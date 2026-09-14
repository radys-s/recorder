import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/web_answer_service.dart';
import 'package:recorder/core/constants.dart';

/// Plays back [script] one entry per call; the last entry repeats. An entry is
/// either an [LlmCompletion] to return or an exception to throw.
class _ScriptedLlm extends LlmProvider {
  _ScriptedLlm(this.script);

  final List<Object> script;
  final calls = <List<LlmMessage>>[];
  final models = <String>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    calls.add(messages);
    models.add(model);
    final next = script.length > 1 ? script.removeAt(0) : script.first;
    if (next is Exception) throw next;
    return next as LlmCompletion;
  }
}

const _searchTools = [
  {
    'type': 'search',
    'arguments': '{"query": "sazba CNB"}',
    // Groq nests the results as a JSON document inside a string.
    'output': '{"results": ['
        '{"title": "ČNB", "url": "https://www.cnb.cz/sazby"},'
        '{"title": "Kurzy", "url": "https://kurzy.cz/x"},'
        '{"title": "ČNB again", "url": "https://cnb.cz/jina"},'
        '{"title": "Bad", "url": "javascript:alert(1)"},'
        '{"title": "Fintag", "url": "https://fintag.cz/a"},'
        '{"title": "Fourth", "url": "https://example.com"}'
        ']}',
  },
];

LlmCompletion _searched(String content) =>
    LlmCompletion(content: content, executedTools: _searchTools);

const _question = 'Jaká je teď základní sazba ČNB?';

void main() {
  test('a blank question makes no call', () async {
    final llm = _ScriptedLlm([_searched('x')]);
    expect(await WebAnswerService(llm).lookUp('   '), isNull);
    expect(llm.calls, isEmpty);
  });

  test('only the question leaves the device, and sources come from the search',
      () async {
    final llm = _ScriptedLlm([
      _searched('Základní sazba je 3,5 %.\n\n- https://www.cnb.cz/sazby\n'
          '[https://kurzy.cz/x]'),
    ]);
    final web = await WebAnswerService(llm).lookUp('  $_question ');

    expect(web, isNotNull);
    expect(web!.answer, 'Základní sazba je 3,5 %.');
    expect(web.sources.map((s) => s.domain), ['cnb.cz', 'kurzy.cz', 'fintag.cz']);

    expect(llm.models.single, kGroqWebAnswerModel);
    final messages = llm.calls.single;
    expect(messages.map((m) => m.role), ['system', 'user']);
    expect(messages.last.content, _question);
  });

  test('no search run means no web badge', () async {
    final llm = _ScriptedLlm([const LlmCompletion(content: 'Asi 3,5 %.')]);
    expect(await WebAnswerService(llm).lookUp(_question), isNull);
  });

  test('an answer that was nothing but links is no answer', () async {
    final llm = _ScriptedLlm([_searched('https://www.cnb.cz/sazby')]);
    expect(await WebAnswerService(llm).lookUp(_question), isNull);
  });

  test("the model's own source list is the fallback, not the first choice",
      () async {
    final llm = _ScriptedLlm([
      const LlmCompletion(
        content: '{"answer": "Ano, platí od května.", '
            '"sources": [{"title": "X", "url": "https://x.cz/a"}]}',
        executedTools: [
          {'type': 'search', 'output': 'no structured results'},
        ],
      ),
    ]);
    final web = await WebAnswerService(llm).lookUp(_question);
    expect(web!.answer, 'Ano, platí od května.');
    expect(web.sources.single.domain, 'x.cz');
  });

  group('retries', () {
    const tooLarge = AiTransientException('request too large', statusCode: 413);

    test('a 413 is tossed again until one gets through', () async {
      final llm = _ScriptedLlm([tooLarge, tooLarge, _searched('Je to 3,5 %.')]);
      final web = await WebAnswerService(llm).lookUp(_question);
      expect(web!.answer, 'Je to 3,5 %.');
      expect(llm.calls, hasLength(3));
    });

    test('an instant 413 cannot spin past the attempt cap', () async {
      final llm = _ScriptedLlm([tooLarge]);
      expect(await WebAnswerService(llm).lookUp(_question), isNull);
      expect(llm.calls, hasLength(kWebMaxAttempts));
    });

    test('a 429 whose wait outlasts the budget ends it at once', () async {
      final llm = _ScriptedLlm([
        const AiTransientException(
          'Rate limit reached. Please try again in 48.2s.',
          statusCode: 429,
        ),
        _searched('never reached'),
      ]);
      expect(await WebAnswerService(llm).lookUp(_question), isNull);
      expect(llm.calls, hasLength(1));
    });

    test('a 429 with a short wait is retried after it', () async {
      final llm = _ScriptedLlm([
        const AiTransientException(
          'Rate limit reached. Please try again in 0.02s.',
          statusCode: 429,
        ),
        _searched('Je to 3,5 %.'),
      ]);
      expect((await WebAnswerService(llm).lookUp(_question))!.answer,
          'Je to 3,5 %.');
      expect(llm.calls, hasLength(2));
    });

    test('other failures are not coin flips and are not retried', () async {
      for (final failure in [
        const AiPermanentException('bad key', statusCode: 401),
        const AiTransientException('bad gateway', statusCode: 503),
        const AiTransientException('Network problem: connectionError'),
      ]) {
        final llm = _ScriptedLlm([failure, _searched('never reached')]);
        expect(await WebAnswerService(llm).lookUp(_question), isNull);
        expect(llm.calls, hasLength(1), reason: failure.toString());
      }
    });
  });
}
