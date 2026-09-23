import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/answer_source.dart';
import 'package:recorder/ai/gemini_provider.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/web_answer_service.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/secure/api_key_store.dart';

class _KeyStore implements ApiKeyStore {
  @override
  Future<String?> read() async => 'test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SearchGemini extends GeminiProvider {
  _SearchGemini(this._script) : super(_KeyStore());

  final List<Object> _script;
  final calls = <({String model, List<LlmMessage> messages, bool search})>[];

  @override
  Future<GeminiCompletion> generate({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    bool search = false,
    bool jsonMode = false,
    int? maxTokens,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    calls.add((model: model, messages: messages, search: search));
    final next = _script.length > 1 ? _script.removeAt(0) : _script.single;
    if (next is Exception) throw next;
    return next as GeminiCompletion;
  }
}

const _question = 'Jaká je teď základní sazba ČNB?';
final _sources = [
  AnswerSource(title: 'ČNB', url: Uri.parse('https://www.cnb.cz/sazby')),
  AnswerSource(title: 'Kurzy', url: Uri.parse('https://kurzy.cz/x')),
];

GeminiCompletion _grounded(String text) =>
    GeminiCompletion(content: text, sources: _sources);

void main() {
  test('a blank question makes no call', () async {
    final gemini = _SearchGemini([_grounded('x')]);
    final service = WebAnswerService(gemini, hasGeminiKey: () async => true);

    expect(await service.lookUp('   '), isNull);
    expect(gemini.calls, isEmpty);
  });

  test('only the question is sent to grounded search', () async {
    final gemini = _SearchGemini([
      _grounded('Základní sazba je 3,5 %.\nhttps://www.cnb.cz/sazby'),
    ]);
    final service = WebAnswerService(gemini, hasGeminiKey: () async => true);

    final web = await service.lookUp('  $_question ');

    expect(web, isNotNull);
    expect(web!.answer, 'Základní sazba je 3,5 %.');
    expect(web.sources.map((s) => s.domain), ['cnb.cz', 'kurzy.cz']);
    expect(gemini.calls.single.model, kGeminiModel);
    expect(gemini.calls.single.search, isTrue);
    expect(gemini.calls.single.messages.map((m) => m.role), ['system', 'user']);
    expect(gemini.calls.single.messages.last.content, _question);
  });

  test('an unavailable Gemini key keeps the honest non-web answer', () async {
    final gemini = _SearchGemini([_grounded('never sent')]);
    final service = WebAnswerService(gemini, hasGeminiKey: () async => false);

    expect(await service.lookUp(_question), isNull);
    expect(gemini.calls, isEmpty);
  });

  test('a downgraded search response never earns a web badge', () async {
    final gemini = _SearchGemini([
      const GeminiCompletion(content: 'Možná 3,5 %.', grounded: false),
    ]);
    final service = WebAnswerService(gemini, hasGeminiKey: () async => true);

    expect(await service.lookUp(_question), isNull);
  });

  test('grounding without a usable source never earns a web badge', () async {
    final gemini = _SearchGemini([
      const GeminiCompletion(content: 'Možná 3,5 %.', sources: []),
    ]);
    final service = WebAnswerService(gemini, hasGeminiKey: () async => true);

    expect(await service.lookUp(_question), isNull);
  });

  test(
    'a provider failure is swallowed and leaves the first answer intact',
    () async {
      final gemini = _SearchGemini([
        const AiTransientException('rate limited', statusCode: 429),
      ]);
      final service = WebAnswerService(gemini, hasGeminiKey: () async => true);

      expect(await service.lookUp(_question), isNull);
    },
  );

  test('stripTrailingLinks keeps a URL used inside a sentence', () {
    expect(
      stripTrailingLinks('Zdroj je https://www.cnb.cz/sazby a platí dnes.'),
      'Zdroj je https://www.cnb.cz/sazby a platí dnes.',
    );
  });
}
