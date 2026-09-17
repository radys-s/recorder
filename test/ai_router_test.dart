import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/ai_router.dart';
import 'package:recorder/ai/gemini_provider.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/openai_compatible_provider.dart';
import 'package:recorder/ai/vision_fallback.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/core/gemini_failure.dart';
import 'package:recorder/data/secure/api_key_store.dart';

class _Keys implements ApiKeyStore {
  _Keys(this.key);
  String? key;

  @override
  Future<String?> read() async => key;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A provider that answers from a script instead of the network.
class _Scripted extends OpenAiCompatibleProvider {
  _Scripted(String? key, this.vendorName, this.script)
    : keys = _Keys(key),
      super(_Keys(key), vendor: vendorName, baseUrl: _none);

  final _Keys keys;
  final String vendorName;

  /// Per model id: the answer, or an exception to throw.
  final Object Function(String model) script;
  final calls = <String>[];
  final imageCounts = <int>[];

  static Future<String?> _none() async => 'https://example.invalid';

  @override
  ApiKeyStore get keyStore => keys;

  @override
  Future<LlmCompletion> completeWithImages({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    calls.add(model);
    imageCounts.add(images.length);
    final out = script(model);
    if (out is Exception) throw out;
    return LlmCompletion(content: out as String);
  }
}

AiRoute _route(
  AiVendor vendor,
  _Scripted provider, {
  List<String> fast = const ['f'],
  List<String> strong = const ['s1', 's2'],
  List<String> vision = const [],
  int? maxInputTokens,
  bool requestedOnly = false,
}) => AiRoute(
  vendor: vendor,
  provider: provider,
  maxInputTokens: maxInputTokens,
  models: (tier, requested) async => requestedOnly
      ? (tier == AiTier.vision || requested.isEmpty ? [] : [requested])
      : switch (tier) {
          AiTier.fast => fast,
          AiTier.strong => strong,
          AiTier.vision => vision,
        },
);

const _msgs = [LlmMessage.user('Ahoj')];

class _Clock {
  DateTime now = DateTime(2026, 9, 17, 10);
}

void main() {
  group('orderFor', () {
    test('fast, strong, large strong and vision', () {
      expect(
        RoutedLlmProvider.orderFor(kGroqCorrectionModel, 10, AiTier.fast),
        [AiVendor.custom, AiVendor.cerebras, AiVendor.groq, AiVendor.mistral],
      );
      expect(RoutedLlmProvider.orderFor(kGroqAnswerModel, 10, AiTier.strong), [
        AiVendor.custom,
        AiVendor.cerebras,
        AiVendor.mistral,
        AiVendor.groq,
      ]);
      expect(
        RoutedLlmProvider.orderFor(
          kGroqAnswerModel,
          kRouterLargeInputTokens + 1,
          AiTier.strong,
        ),
        [AiVendor.custom, AiVendor.mistral, AiVendor.cerebras, AiVendor.groq],
      );
      expect(RoutedLlmProvider.orderFor('', 0, AiTier.vision), [
        AiVendor.custom,
        AiVendor.mistral,
      ]);
      expect(
        RoutedLlmProvider.orderFor(kGroqWebAnswerModel, 10, AiTier.strong),
        [AiVendor.groq],
      );
    });

    test('tier and token estimate', () {
      expect(RoutedLlmProvider.tierFor(kGroqCorrectionModel), AiTier.fast);
      expect(RoutedLlmProvider.tierFor(kGroqAnswerModel), AiTier.strong);
      expect(
        RoutedLlmProvider.estimateTokens(const [LlmMessage.user('abcdefg')]),
        3,
      );
    });
  });

  group('RoutedLlmProvider', () {
    test('skips services without a key and uses the first with one', () async {
      final cerebras = _Scripted(null, 'Cerebras', (_) => 'c');
      final mistral = _Scripted('m_test', 'Mistral', (_) => 'm');
      final groq = _Scripted('gsk_test', 'Groq', (_) => 'g');
      final router = RoutedLlmProvider(
        routes: [
          _route(AiVendor.cerebras, cerebras),
          _route(AiVendor.mistral, mistral),
          _route(AiVendor.groq, groq, requestedOnly: true),
        ],
        health: AiRouteHealth(),
      );
      final out = await router.complete(
        model: kGroqAnswerModel,
        messages: _msgs,
      );
      expect(out, 'm');
      expect(cerebras.calls, isEmpty);
      expect(groq.calls, isEmpty);
    });

    test('only Groq keeps the requested model', () async {
      final groq = _Scripted('gsk_test', 'Groq', (m) => m);
      final router = RoutedLlmProvider(
        routes: [_route(AiVendor.groq, groq, requestedOnly: true)],
        health: AiRouteHealth(),
      );
      expect(
        await router.complete(model: kGroqAnswerModel, messages: _msgs),
        kGroqAnswerModel,
      );
    });

    test('no service at all keeps the old Groq message', () async {
      final router = RoutedLlmProvider(
        routes: [
          _route(AiVendor.mistral, _Scripted(null, 'Mistral', (_) => '')),
        ],
        health: AiRouteHealth(),
      );
      await expectLater(
        router.complete(model: kGroqAnswerModel, messages: _msgs),
        throwsA(
          isA<AiPermanentException>().having(
            (e) => e.message,
            'message',
            'No Groq API key configured. Add one in Settings.',
          ),
        ),
      );
    });

    test('a 429 rests the service, moves on, and backs off', () async {
      final clock = _Clock();
      final health = AiRouteHealth(now: () => clock.now);
      final cerebras = _Scripted(
        'c_test',
        'Cerebras',
        (_) => const AiTransientException('limit', statusCode: 429),
      );
      final groq = _Scripted('gsk_test', 'Groq', (_) => 'g');
      final router = RoutedLlmProvider(
        routes: [
          _route(AiVendor.cerebras, cerebras),
          _route(AiVendor.groq, groq, requestedOnly: true),
        ],
        health: health,
      );

      expect(
        await router.complete(model: kGroqAnswerModel, messages: _msgs),
        'g',
      );
      expect(cerebras.calls, ['s1'], reason: 'a limit skips the other models');
      expect(
        health.cooldownUntil(AiVendor.cerebras),
        clock.now.add(kRouteCooldown),
      );

      // Rested services go first: Groq now leads, Cerebras is not touched.
      await router.complete(model: kGroqAnswerModel, messages: _msgs);
      expect(cerebras.calls, ['s1']);

      // After the rest it is tried again; a second 429 doubles the wait.
      clock.now = clock.now.add(kRouteCooldown + const Duration(seconds: 1));
      await router.complete(model: kGroqAnswerModel, messages: _msgs);
      expect(cerebras.calls, ['s1', 's1']);
      expect(
        health.cooldownUntil(AiVendor.cerebras),
        clock.now.add(kRouteCooldown * 2),
      );
    });

    test('retry-after sets the rest; the ceiling caps doubling', () {
      final clock = _Clock();
      final health = AiRouteHealth(now: () => clock.now);
      health.cool(AiVendor.mistral, const Duration(seconds: 7));
      expect(
        health.cooldownUntil(AiVendor.mistral),
        clock.now.add(const Duration(seconds: 7)),
      );
      for (var i = 0; i < 20; i++) {
        health.cool(AiVendor.groq, null);
      }
      expect(
        health.cooldownUntil(AiVendor.groq),
        clock.now.add(kRouteMaxCooldown),
      );
      health.succeeded(AiVendor.groq, 'x');
      expect(health.coolingDown(AiVendor.groq), isFalse);
      expect(health.lastModel(AiVendor.groq), 'x');
    });

    test(
      'cooling services are still tried when nothing else is left',
      () async {
        final clock = _Clock();
        final health = AiRouteHealth(now: () => clock.now)
          ..cool(AiVendor.mistral, null);
        final mistral = _Scripted('m_test', 'Mistral', (_) => 'm');
        final router = RoutedLlmProvider(
          routes: [_route(AiVendor.mistral, mistral)],
          health: health,
        );
        expect(
          await router.complete(model: kGroqAnswerModel, messages: _msgs),
          'm',
        );
        expect(health.coolingDown(AiVendor.mistral), isFalse);
      },
    );

    test('a refused key disables that key until it changes', () async {
      final mistral = _Scripted(
        'm_old',
        'Mistral',
        (_) => const AiPermanentException('bad key', statusCode: 401),
      );
      final groq = _Scripted('gsk_test', 'Groq', (_) => 'g');
      final health = AiRouteHealth();
      final router = RoutedLlmProvider(
        routes: [
          _route(AiVendor.mistral, mistral),
          _route(AiVendor.groq, groq, requestedOnly: true),
        ],
        health: health,
      );
      expect(
        await router.complete(model: kGroqAnswerModel, messages: _msgs),
        'g',
      );
      expect(health.anyDisabled(AiVendor.mistral), isTrue);
      await router.complete(model: kGroqAnswerModel, messages: _msgs);
      expect(mistral.calls, ['s1'], reason: 'the refused key is not retried');

      mistral.keys.key = 'm_new';
      await router.complete(model: kGroqAnswerModel, messages: _msgs);
      expect(mistral.calls, ['s1', 's1']);
    });

    test('a 404 tries the same service next model', () async {
      final mistral = _Scripted(
        'm_test',
        'Mistral',
        (m) => m == 's1'
            ? const AiPermanentException('no model', statusCode: 404)
            : 'from $m',
      );
      final router = RoutedLlmProvider(
        routes: [_route(AiVendor.mistral, mistral)],
        health: AiRouteHealth(),
      );
      expect(
        await router.complete(model: kGroqAnswerModel, messages: _msgs),
        'from s2',
      );
    });

    test('a network failure stops instead of trying every service', () async {
      final cerebras = _Scripted(
        'c_test',
        'Cerebras',
        (_) => const AiTransientException('offline'),
      );
      final groq = _Scripted('gsk_test', 'Groq', (_) => 'g');
      final health = AiRouteHealth();
      final router = RoutedLlmProvider(
        routes: [
          _route(AiVendor.cerebras, cerebras),
          _route(AiVendor.groq, groq, requestedOnly: true),
        ],
        health: health,
      );
      await expectLater(
        router.complete(model: kGroqAnswerModel, messages: _msgs),
        throwsA(isA<AiTransientException>()),
      );
      expect(groq.calls, isEmpty);
      expect(health.coolingDown(AiVendor.cerebras), isFalse);
    });

    test('everything failing throws the transient error first', () async {
      final a = _Scripted(
        'c_test',
        'Cerebras',
        (_) => const AiTransientException('busy', statusCode: 503),
      );
      final b = _Scripted(
        'm_test',
        'Mistral',
        (_) => const AiPermanentException('bad request', statusCode: 400),
      );
      final router = RoutedLlmProvider(
        routes: [_route(AiVendor.cerebras, a), _route(AiVendor.mistral, b)],
        health: AiRouteHealth(),
      );
      await expectLater(
        router.complete(model: kGroqAnswerModel, messages: _msgs),
        throwsA(
          isA<AiTransientException>().having(
            (e) => e.message,
            'message',
            'busy',
          ),
        ),
      );
    });

    test('an oversized request skips a small service', () async {
      final cerebras = _Scripted('c_test', 'Cerebras', (_) => 'c');
      final mistral = _Scripted('m_test', 'Mistral', (_) => 'm');
      final router = RoutedLlmProvider(
        routes: [
          _route(AiVendor.cerebras, cerebras, maxInputTokens: 100),
          _route(AiVendor.mistral, mistral),
        ],
        health: AiRouteHealth(),
      );
      final big = [LlmMessage.user('x' * 400)];
      expect(
        await router.complete(model: kGroqAnswerModel, messages: big),
        'm',
      );
      expect(cerebras.calls, isEmpty);
    });

    test('fast tier uses the fast model list', () async {
      final cerebras = _Scripted('c_test', 'Cerebras', (m) => m);
      final router = RoutedLlmProvider(
        routes: [
          _route(AiVendor.cerebras, cerebras, fast: ['quick']),
        ],
        health: AiRouteHealth(),
      );
      expect(
        await router.complete(model: kGroqCorrectionModel, messages: _msgs),
        'quick',
      );
    });

    test('vision goes only to services with vision models', () async {
      final cerebras = _Scripted('c_test', 'Cerebras', (_) => 'c');
      final mistral = _Scripted('m_test', 'Mistral', (_) => 'seen');
      final router = RoutedLlmProvider(
        routes: [
          _route(AiVendor.cerebras, cerebras),
          _route(AiVendor.mistral, mistral, vision: ['pixtral']),
        ],
        health: AiRouteHealth(),
      );
      expect(await router.hasVisionRoute(), isTrue);
      final out = await router.completeVision(
        messages: _msgs,
        images: [
          LlmImage(Uint8List.fromList([1, 2])),
        ],
      );
      expect(out.content, 'seen');
      expect(mistral.imageCounts, [1]);
      expect(cerebras.calls, isEmpty);
    });

    test('no vision key names Gemini or Mistral', () async {
      final router = RoutedLlmProvider(
        routes: [
          _route(
            AiVendor.mistral,
            _Scripted(null, 'Mistral', (_) => ''),
            vision: ['pixtral'],
          ),
        ],
        health: AiRouteHealth(),
      );
      expect(await router.hasVisionRoute(), isFalse);
      await expectLater(
        router.completeVision(messages: _msgs, images: const []),
        throwsA(
          isA<AiPermanentException>().having(
            (e) => e.message,
            'message',
            contains('Mistral'),
          ),
        ),
      );
    });
  });

  group('GeminiWithVisionFallback', () {
    GeminiWithVisionFallback build(
      List<(int, Object)> replies, {
      String? geminiKey = 'AIza_test',
      String? mistralKey = 'm_test',
    }) {
      final adapter = _SeqAdapter(replies);
      final mistral = _Scripted(mistralKey, 'Mistral', (_) => 'z Mistralu');
      return GeminiWithVisionFallback(
        _Keys(geminiKey),
        router: RoutedLlmProvider(
          routes: [
            _route(AiVendor.mistral, mistral, vision: ['pixtral']),
          ],
          health: AiRouteHealth(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
        overloadDelay: Duration.zero,
      );
    }

    final photo = [
      LlmImage(Uint8List.fromList([1])),
    ];
    final busy = (
      503,
      _geminiError(503, 'The model is overloaded.', 'UNAVAILABLE'),
    );

    test('Gemini busy with a photo falls back to Mistral', () async {
      final llm = build([busy, busy, busy]);
      final out = await llm.generate(
        model: kGeminiModel,
        messages: _msgs,
        images: photo,
      );
      expect(out.content, 'z Mistralu');
    });

    test('without a picture the Gemini error stays', () async {
      final llm = build([busy, busy, busy]);
      await expectLater(
        llm.generate(model: kGeminiModel, messages: _msgs),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            GeminiErrorKind.overloaded,
          ),
        ),
      );
    });

    test('a PDF is not sent to Mistral', () async {
      final llm = build([busy, busy, busy]);
      await expectLater(
        llm.generate(
          model: kGeminiModel,
          messages: _msgs,
          images: [
            LlmImage(Uint8List.fromList([1]), mimeType: 'application/pdf'),
          ],
        ),
        throwsA(isA<AiException>()),
      );
    });

    test('no Gemini key but Mistral: the photo is still read', () async {
      final llm = build(const [], geminiKey: null);
      final out = await llm.generate(
        model: kGeminiModel,
        messages: _msgs,
        images: photo,
      );
      expect(out.content, 'z Mistralu');
    });

    test('no vision key anywhere keeps the Gemini message', () async {
      final llm = build(const [], geminiKey: null, mistralKey: null);
      await expectLater(
        llm.generate(model: kGeminiModel, messages: _msgs, images: photo),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            startsWith('Chybí Gemini'),
          ),
        ),
      );
    });
  });

  group('Gemini overload', () {
    test('retries once, then the lite model', () async {
      final adapter = _SeqAdapter([
        (503, _geminiError(503, 'The model is overloaded.', 'UNAVAILABLE')),
        (503, _geminiError(503, 'The model is overloaded.', 'UNAVAILABLE')),
        (200, _geminiOk('lite')),
      ]);
      final llm = GeminiProvider(
        _Keys('AIza_test'),
        dio: Dio()..httpClientAdapter = adapter,
        overloadDelay: Duration.zero,
      );
      final out = await llm.generate(model: kGeminiModel, messages: _msgs);
      expect(out.content, 'lite');
      expect(adapter.paths[0], contains('$kGeminiModel:'));
      expect(adapter.paths[1], contains('$kGeminiModel:'));
      expect(adapter.paths[2], contains('$kGeminiLiteModel:'));
    });

    test('the lite model busy too gives the overload message', () async {
      final err = (503, _geminiError(503, 'overloaded', 'UNAVAILABLE'));
      final adapter = _SeqAdapter([err, err, err, err]);
      final llm = GeminiProvider(
        _Keys('AIza_test'),
        dio: Dio()..httpClientAdapter = adapter,
        overloadDelay: Duration.zero,
      );
      await expectLater(
        llm.generate(model: kGeminiModel, messages: _msgs),
        throwsA(
          isA<AiTransientException>().having(
            (e) => e.kind,
            'kind',
            GeminiErrorKind.overloaded,
          ),
        ),
      );
      expect(adapter.paths, hasLength(3));
    });
  });

  group('OpenAI-compatible wire format', () {
    test('Mistral content chunks are joined', () {
      final out = parseOpenAiCompletion({
        'choices': [
          {
            'message': {
              'content': [
                {'type': 'text', 'text': 'Ahoj '},
                {
                  'type': 'reference',
                  'ids': [1],
                },
                {'type': 'text', 'text': 'světe'},
              ],
            },
          },
        ],
      });
      expect(out.content, 'Ahoj světe');
    });

    test('images join the last user message as data URIs', () {
      final built = buildOpenAiMessages(
        const [LlmMessage.system('s'), LlmMessage.user('co je na fotce?')],
        [
          LlmImage(Uint8List.fromList([1, 2, 3]), mimeType: 'image/png'),
        ],
      );
      expect(built.first, {'role': 'system', 'content': 's'});
      final parts = built.last['content'] as List;
      expect((parts.first as Map)['image_url'], {
        'url': 'data:image/png;base64,AQID',
      });
      expect(parts.last, {'type': 'text', 'text': 'co je na fotce?'});
    });

    test('addresses and retry-after', () {
      expect(
        chatCompletionsUrl('https://x/v1/'),
        'https://x/v1/chat/completions',
      );
      expect(
        chatCompletionsUrl('https://x/v1/chat/completions'),
        'https://x/v1/chat/completions',
      );
      expect(parseRetryAfter(' 2.5 '), const Duration(milliseconds: 2500));
      expect(parseRetryAfter('Wed, 21 Oct'), isNull);
      expect(parseRetryAfter(null), isNull);
    });

    test('a 429 carries retry-after and names the vendor on 401', () async {
      final limited = _SeqAdapter(
        [
          (
            429,
            {
              'error': {'message': 'rate limit'},
            },
          ),
        ],
        headers: {
          'retry-after': ['12'],
        },
      );
      final mistral = OpenAiCompatibleProvider(
        _Keys('m_test'),
        vendor: 'Mistral',
        baseUrl: () async => kMistralBaseUrl,
        dio: Dio()..httpClientAdapter = limited,
      );
      await expectLater(
        mistral.complete(model: 'mistral-small-latest', messages: _msgs),
        throwsA(
          isA<AiTransientException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 12),
          ),
        ),
      );
      expect(limited.paths.single, '$kMistralBaseUrl/chat/completions');
      expect(limited.bodies.single.containsKey('reasoning_effort'), isFalse);

      final refused = _SeqAdapter([
        (
          401,
          {
            'error': {'message': 'Unauthorized'},
          },
        ),
      ]);
      final cerebras = OpenAiCompatibleProvider(
        _Keys('c_test'),
        vendor: 'Cerebras',
        baseUrl: () async => kCerebrasBaseUrl,
        dio: Dio()..httpClientAdapter = refused,
      );
      await expectLater(
        cerebras.complete(model: 'x', messages: _msgs),
        throwsA(
          isA<AiPermanentException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('no key or no address sends nothing', () async {
      final adapter = _SeqAdapter(const []);
      final noKey = OpenAiCompatibleProvider(
        _Keys(null),
        vendor: 'Mistral',
        baseUrl: () async => kMistralBaseUrl,
        dio: Dio()..httpClientAdapter = adapter,
      );
      await expectLater(
        noKey.complete(model: 'x', messages: _msgs),
        throwsA(
          isA<AiPermanentException>().having(
            (e) => e.message,
            'message',
            contains('Mistral'),
          ),
        ),
      );
      final noUrl = OpenAiCompatibleProvider(
        _Keys('k'),
        vendor: 'Vlastní',
        baseUrl: () async => '  ',
        dio: Dio()..httpClientAdapter = adapter,
      );
      await expectLater(
        noUrl.complete(model: 'x', messages: _msgs),
        throwsA(isA<AiPermanentException>()),
      );
      expect(adapter.paths, isEmpty);
    });

    test('listOpenAiModels reads ids from /models', () async {
      final adapter = _SeqAdapter([
        (
          200,
          {
            'data': [
              {'id': 'mistral-small-latest'},
              {'id': 'codestral-latest'},
              {'nope': 1},
            ],
          },
        ),
      ]);
      final ids = await listOpenAiModels(
        _Keys('m_test'),
        vendor: 'Mistral',
        baseUrl: 'https://api.mistral.ai/v1/chat/completions',
        dio: Dio()..httpClientAdapter = adapter,
      );
      expect(ids, ['codestral-latest', 'mistral-small-latest']);
      expect(adapter.paths.single, 'https://api.mistral.ai/v1/models');
    });
  });
}

class _SeqAdapter implements HttpClientAdapter {
  _SeqAdapter(this.replies, {this.headers = const {}});

  final List<(int, Object)> replies;
  final Map<String, List<String>> headers;
  final paths = <String>[];
  final bodies = <Map<String, Object?>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    if (requestStream != null) {
      final bytes = await requestStream.expand((b) => b).toList();
      bodies.add(jsonDecode(utf8.decode(bytes)) as Map<String, Object?>);
    }
    final (status, body) = replies[paths.length - 1];
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _geminiOk(String text) => {
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': text},
        ],
      },
      'finishReason': 'STOP',
    },
  ],
};

Map<String, Object?> _geminiError(int code, String message, String status) => {
  'error': {'code': code, 'message': message, 'status': status},
};
