import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/card_digest_service.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/db/app_database.dart';

class _FakeLlm extends LlmProvider {
  _FakeLlm(this.reply, {this.onCall});

  final Object reply; // String, or an exception to throw
  final Future<void> Function()? onCall;
  final models = <String>[];
  final prompts = <String>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    models.add(model);
    prompts.add(messages.last.content);
    await onCall?.call();
    final r = reply;
    if (r is Exception) throw r;
    return LlmCompletion(content: r as String);
  }
}

const _json =
    '{"summary": "Babička je povídka Boženy Němcové.", "keywords": ["Proško", "Viktorka", "proško", ""]}';

void main() {
  late AppDatabase db;
  late int subject;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    subject = await db.savedNotesDao.createFolder('Čeština');
  });
  tearDown(() => db.close());

  Future<int> card(String content) => db.subjectsDao
      .createCard(subjectId: subject, title: 'Babička', content: content);

  test('without a Gemini key the digest is made on Groq and stored', () async {
    final id = await card('Babička, povídka. Postavy: Proško, Viktorka.');
    final groq = _FakeLlm(_json);
    final gemini = _FakeLlm(_json);
    final service = CardDigestService(db.subjectsDao,
        groq: groq, gemini: gemini, hasGeminiKey: () async => false);

    expect(await service.digest(id), isTrue);
    expect(gemini.models, isEmpty);
    expect(groq.models, [kGroqNotesModel]);

    final stored = (await db.subjectsDao.card(id))!;
    expect(stored.summary, 'Babička je povídka Boženy Němcové.');
    expect(stored.keywords, 'Proško, Viktorka');
  });

  test('with a Gemini key the lite model does it; a digest is made once',
      () async {
    final id = await card('Obsah karty.');
    final groq = _FakeLlm(_json);
    final gemini = _FakeLlm(_json);
    final service = CardDigestService(db.subjectsDao,
        groq: groq, gemini: gemini, hasGeminiKey: () async => true);

    expect(await service.digest(id), isTrue);
    expect(await service.digest(id), isFalse);
    expect(gemini.models, [kGeminiLiteModel]);
    expect(groq.models, isEmpty);
  });

  test('an edit that lands while the call is out wins', () async {
    final id = await card('Stará verze.');
    final groq = _FakeLlm(_json, onCall: () async {
      await db.subjectsDao
          .updateCard(id, title: 'Babička', content: 'Nová verze.');
    });
    final service = CardDigestService(db.subjectsDao, groq: groq);

    expect(await service.digest(id), isFalse);
    final stored = (await db.subjectsDao.card(id))!;
    expect(stored.content, 'Nová verze.');
    expect(stored.summary, isNull);
  });

  test('a failure or an empty reply stores nothing and never throws',
      () async {
    final id = await card('Obsah.');
    for (final reply in <Object>[
      const AiTransientException('429'),
      'not json',
      '{"summary": "  "}',
    ]) {
      final service = CardDigestService(db.subjectsDao, groq: _FakeLlm(reply));
      expect(await service.digest(id), isFalse);
    }
    expect((await db.subjectsDao.card(id))!.summary, isNull);
  });

  test('an empty card makes no call; a long one is cut for Groq', () async {
    final empty = await card('   ');
    await card('slovo ' * 3000);
    final groq = _FakeLlm(_json);
    final service = CardDigestService(db.subjectsDao, groq: groq);

    expect(await service.digest(empty), isFalse);
    expect(groq.models, isEmpty);

    await service.digestMissing(subject);
    expect(groq.models, hasLength(1));
    expect(groq.prompts.single.length, lessThan(kDigestGroqChars + 100));
  });

  group('parseCardDigest', () {
    test('clips the summary and accepts keywords as a string', () {
      final d = parseCardDigest(
          '{"summary": "${'a ' * 400}", "keywords": "Máj, Hynek, , Máj"}')!;
      expect(d.summary.length, lessThanOrEqualTo(kCardSummaryMaxChars));
      expect(d.summary, endsWith('…'));
      expect(d.keywords, 'Máj, Hynek');
    });

    test('commas inside a keyword cannot split it', () {
      final d = parseCardDigest(
          '{"summary": "x", "keywords": ["Mácha, Karel Hynek"]}')!;
      expect(d.keywords, 'Mácha  Karel Hynek');
    });
  });
}
