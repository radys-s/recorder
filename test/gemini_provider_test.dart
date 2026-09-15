import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/gemini_models.dart';
import 'package:recorder/ai/gemini_provider.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/secure/api_key_store.dart';

class _FakeKeyStore implements ApiKeyStore {
  _FakeKeyStore(this.key);
  final String? key;

  @override
  Future<String?> read() async => key;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? options;
  Map<String, Object?>? sent;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    if (requestStream != null) {
      final bytes = await requestStream.expand((b) => b).toList();
      sent = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(GeminiProvider, _Adapter) _provider(
  int status,
  Object body, {
  String? key = 'AIza_test',
}) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (GeminiProvider(_FakeKeyStore(key), dio: dio), adapter);
}

// Fixtures in the shape of real `generateContent` responses.

Map<String, Object?> _text(List<Map<String, Object?>> parts,
        {String finish = 'STOP', Object? grounding}) =>
    {
      'candidates': [
        {
          'content': {'role': 'model', 'parts': parts},
          'finishReason': finish,
          'groundingMetadata': ?grounding,
        },
      ],
      'usageMetadata': {'promptTokenCount': 12, 'candidatesTokenCount': 5},
    };

const _grounding = {
  'webSearchQueries': ['Babička Božena Němcová žánr'],
  'groundingChunks': [
    {
      'web': {
        'uri': 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AAA',
        'title': 'cesky-jazyk.cz',
      },
    },
    {
      'web': {
        'uri': 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/BBB',
        'title': 'www.wikipedia.org',
      },
    },
    {
      'web': {
        'uri': 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/CCC',
        'title': 'cesky-jazyk.cz',
      },
    },
    {'retrievedContext': {'uri': 'x'}},
  ],
};

const _invalidKey = {
  'error': {
    'code': 400,
    'message': 'API key not valid. Please pass a valid API key.',
    'status': 'INVALID_ARGUMENT',
    'details': [
      {
        '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
        'reason': 'API_KEY_INVALID',
      },
    ],
  },
};

const _messages = [
  LlmMessage.system('Be brief.'),
  LlmMessage.user('Ahoj'),
  LlmMessage.assistant('Ahoj!'),
  LlmMessage.user('Jaký je to žánr?'),
];

void main() {
  test('no key is a permanent failure, and nothing is sent', () async {
    final (llm, adapter) = _provider(200, _text([{'text': 'x'}]), key: null);
    await expectLater(
      llm.complete(model: 'm', messages: _messages),
      throwsA(isA<AiPermanentException>()),
    );
    expect(adapter.options, isNull);
  });

  test('sends the key in a header, roles mapped, system as instruction',
      () async {
    final (llm, adapter) = _provider(200, _text([{'text': ' Povídka. '}]));
    final text = await llm.complete(
      model: 'gemini-3.5-flash',
      messages: _messages,
      temperature: 0.1,
      maxTokens: 800,
      jsonMode: true,
    );

    expect(text, 'Povídka.');
    expect(adapter.options!.path,
        '$kGeminiBaseUrl/models/gemini-3.5-flash:generateContent');
    expect(adapter.options!.headers['x-goog-api-key'], 'AIza_test');
    // The key never travels in the URL.
    expect(adapter.options!.uri.toString(), isNot(contains('AIza_test')));
    expect(adapter.sent, {
      'systemInstruction': {
        'parts': [
          {'text': 'Be brief.'},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Ahoj'},
          ],
        },
        {
          'role': 'model',
          'parts': [
            {'text': 'Ahoj!'},
          ],
        },
        {
          'role': 'user',
          'parts': [
            {'text': 'Jaký je to žánr?'},
          ],
        },
      ],
      // No temperature: Gemini 3 is meant to run at its default.
      'generationConfig': {
        'maxOutputTokens': 800,
        'responseMimeType': 'application/json',
        'thinkingConfig': {'thinkingLevel': kGeminiThinkingLevel},
      },
    });
  });

  test('images go in front of the last user message, search adds the tool',
      () async {
    final (llm, adapter) = _provider(200, _text([{'text': 'Na tabuli…'}]));
    final image = Uint8List.fromList([1, 2, 3]);
    await llm.generate(
      model: 'm',
      messages: _messages,
      images: [LlmImage(image)],
      search: true,
    );

    final contents = adapter.sent!['contents'] as List;
    expect((contents.first as Map)['parts'], [
      {'text': 'Ahoj'},
    ]);
    expect((contents.last as Map)['parts'], [
      {
        'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(image)},
      },
      {'text': 'Jaký je to žánr?'},
    ]);
    expect(adapter.sent!['tools'], [
      {'googleSearch': <String, Object?>{}},
    ]);
    final config = adapter.sent!['generationConfig'] as Map;
    expect(config.containsKey('maxOutputTokens'), isFalse);
    expect(config.containsKey('responseMimeType'), isFalse);
  });

  test('thought parts are not the answer; text parts are joined', () async {
    final (llm, _) = _provider(
      200,
      _text([
        {'text': 'Let me think about genres…', 'thought': true},
        {'text': 'Lyrickoepická '},
        {'text': 'próza.'},
      ]),
    );
    expect(await llm.complete(model: 'm', messages: _messages),
        'Lyrickoepická próza.');
  });

  test('grounding sources are read, labelled by site and de-duplicated',
      () async {
    final (llm, _) =
        _provider(200, _text([{'text': 'Novela.'}], grounding: _grounding));
    final result = await llm.generate(
      model: 'm',
      messages: _messages,
      search: true,
    );

    expect(result.content, 'Novela.');
    expect([for (final s in result.sources) s.domain],
        ['cesky-jazyk.cz', 'wikipedia.org']);
    expect(result.sources.first.url.host, 'vertexaisearch.cloud.google.com');
  });

  test('a cut-off answer with some text is kept and flagged', () async {
    final (llm, _) =
        _provider(200, _text([{'text': 'Začátek'}], finish: 'MAX_TOKENS'));
    final result = await llm.generate(model: 'm', messages: _messages);
    expect(result.content, 'Začátek');
    expect(result.truncated, isTrue);
  });

  group('no usable answer is a permanent failure, never a TypeError', () {
    final bodies = <String, Object>{
      'blocked prompt': {
        'promptFeedback': {'blockReason': 'SAFETY'},
      },
      'no candidates': {'candidates': <Object>[]},
      'safety stop without text': _text(const [], finish: 'SAFETY'),
      'only thoughts, out of tokens': _text([
        {'text': 'thinking', 'thought': true},
      ], finish: 'MAX_TOKENS'),
      'parts not a list': {
        'candidates': [
          {
            'content': {'parts': 'x'},
          },
        ],
      },
      'top level is a list': ['x'],
    };
    bodies.forEach((name, body) {
      test(name, () async {
        final (llm, _) = _provider(200, body);
        await expectLater(
          llm.complete(model: 'm', messages: _messages),
          throwsA(isA<AiPermanentException>()),
        );
      });
    });
  });

  test('an invalid key (Google answers 400) is permanent and says Gemini',
      () async {
    final (llm, _) = _provider(400, _invalidKey);
    await expectLater(
      llm.complete(model: 'm', messages: _messages),
      throwsA(
        isA<AiPermanentException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', contains('Gemini klíč')),
      ),
    );
  });

  test('a rate limit is transient', () async {
    final (llm, _) = _provider(429, {
      'error': {
        'code': 429,
        'message': 'Resource has been exhausted (e.g. check quota).',
        'status': 'RESOURCE_EXHAUSTED',
      },
    });
    await expectLater(
      llm.complete(model: 'm', messages: _messages),
      throwsA(
        isA<AiTransientException>()
            .having((e) => e.statusCode, 'statusCode', 429),
      ),
    );
  });

  test('a retired model is permanent', () async {
    final (llm, _) = _provider(404, {
      'error': {'code': 404, 'message': 'models/x is not found'},
    });
    await expectLater(
      llm.complete(model: 'x', messages: _messages),
      throwsA(isA<AiPermanentException>()),
    );
  });

  group('listGeminiModels', () {
    test('keeps generating models, strips the prefix, sorts', () async {
      final adapter = _Adapter(200, {
        'models': [
          {
            'name': 'models/gemini-3.5-flash',
            'supportedGenerationMethods': ['generateContent', 'countTokens'],
          },
          {
            'name': 'models/text-embedding-004',
            'supportedGenerationMethods': ['embedContent'],
          },
          {'name': 'models/gemini-3.5-flash-lite'},
        ],
      });
      final ids = await listGeminiModels(
        _FakeKeyStore('AIza_test'),
        dio: Dio()..httpClientAdapter = adapter,
      );
      expect(ids, ['gemini-3.5-flash', 'gemini-3.5-flash-lite']);
      expect(adapter.options!.headers['x-goog-api-key'], 'AIza_test');
    });

    test('a bad key fails with the Gemini message', () async {
      await expectLater(
        listGeminiModels(
          _FakeKeyStore('AIza_test'),
          dio: Dio()..httpClientAdapter = _Adapter(400, _invalidKey),
        ),
        throwsA(isA<AiPermanentException>()
            .having((e) => e.message, 'message', contains('Gemini klíč'))),
      );
    });
  });
}
