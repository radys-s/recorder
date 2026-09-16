import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/card_suggestions.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';

class _Llm extends LlmProvider {
  _Llm(this.reply);
  final String reply;
  final models = <String>[];
  final users = <String>[];

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
    users.add(messages.last.content);
    return LlmCompletion(content: reply);
  }
}

const _reply = '{"cards": [{"title": "Realismus", "content": "- směr 19. století"}]}';

void main() {
  group('parseCardSuggestions', () {
    test('existing titles and repeats are skipped without case or diacritics',
        () {
      const raw = '''{"cards": [
        {"title": "babicka", "content": "x"},
        {"title": "Realismus", "content": "- a"},
        {"title": "REALISMUS", "content": "- b"},
        {"title": "  ", "content": "- c"},
        {"title": "Máj", "content": ""},
        {"title": "Romantismus", "content": "- d"}
      ]}''';
      final out = parseCardSuggestions(raw, ['Babička']);
      expect(out.map((s) => s.title), ['Realismus', 'Romantismus']);
    });

    test('at most three, titles capped', () {
      final raw = '{"cards": [${[
        for (var i = 0; i < 5; i++) '{"title": "T$i${'x' * 300}", "content": "c"}'
      ].join(',')}]}';
      final out = parseCardSuggestions(raw, const []);
      expect(out, hasLength(kMaxCardSuggestions));
      expect(out.first.title.length, lessThanOrEqualTo(120));
    });

    test('malformed replies give nothing', () {
      expect(parseCardSuggestions('nic', const []), isEmpty);
      expect(parseCardSuggestions('{"cards": "x"}', const []), isEmpty);
      expect(parseCardSuggestions('{"cards": [1, null]}', const []), isEmpty);
    });

    test('encode/decode round-trip; empty and broken stored forms', () {
      const list = [CardSuggestion(title: 'A', content: 'b')];
      expect(decodeCardSuggestions(encodeCardSuggestions(list)), list);
      expect(encodeCardSuggestions(const []), isNull);
      expect(decodeCardSuggestions(null), isEmpty);
      expect(decodeCardSuggestions('{oops'), isEmpty);
      expect(decodeCardSuggestions('[{"title": 1}]'), isEmpty);
    });
  });

  group('CardSuggestionService', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> lesson({bool withSubject = true}) async {
      final cz = await db.savedNotesDao.createFolder('Čeština');
      await db.subjectsDao.createCard(subjectId: cz, title: 'Babička');
      final id = await db.meetingsDao.insertMeeting(MeetingsCompanion.insert(
        title: 'Hodina',
        createdAt: DateTime(2026, 9, 16, 8),
        subjectId: Value(withSubject ? cz : null),
      ));
      await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
      await db.meetingNotesDao.markReady(id, 'Výpisky');
      return id;
    }

    test('stores suggestions on Groq without a Gemini key', () async {
      final id = await lesson();
      final groq = _Llm(_reply);
      final gemini = _Llm(_reply);
      await CardSuggestionService(db,
              groq: groq, gemini: gemini, hasGeminiKey: () async => false)
          .suggest(id, 'Výpisky');

      expect(groq.models, [kGroqNotesModel]);
      expect(gemini.models, isEmpty);
      expect(groq.users.single, contains('- Babička'));
      final row = (await db.meetingNotesDao.forMeeting(id))!;
      expect(decodeCardSuggestions(row.cardSuggestions).single.title, 'Realismus');
    });

    test('uses Gemini lite with a key', () async {
      final id = await lesson();
      final groq = _Llm(_reply);
      final gemini = _Llm(_reply);
      await CardSuggestionService(db,
              groq: groq, gemini: gemini, hasGeminiKey: () async => true)
          .suggest(id, 'Výpisky');
      expect(gemini.models, [kGeminiLiteModel]);
      expect(groq.models, isEmpty);
    });

    test('a meeting without a subject gets no call', () async {
      final id = await lesson(withSubject: false);
      final groq = _Llm(_reply);
      await CardSuggestionService(db, groq: groq).suggest(id, 'Výpisky');
      expect(groq.models, isEmpty);
    });

    test('notes changed meanwhile: nothing stored', () async {
      final id = await lesson();
      await CardSuggestionService(db, groq: _Llm(_reply)).suggest(id, 'Starší výpisky');
      expect((await db.meetingNotesDao.forMeeting(id))!.cardSuggestions, isNull);
    });

    test('regenerating clears old suggestions', () async {
      final id = await lesson();
      await CardSuggestionService(db, groq: _Llm(_reply)).suggest(id, 'Výpisky');
      await db.meetingNotesDao.markReady(id, 'Nové');
      expect((await db.meetingNotesDao.forMeeting(id))!.cardSuggestions, isNull);
    });
  });
}
