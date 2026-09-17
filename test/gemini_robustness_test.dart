import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/card_lookup_service.dart';
import 'package:recorder/ai/gemini_key_check.dart';
import 'package:recorder/ai/gemini_model_resolver.dart';
import 'package:recorder/ai/gemini_provider.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/photo_text_service.dart';
import 'package:recorder/ai/web_answer_service.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/core/gemini_failure.dart';
import 'package:recorder/data/secure/api_key_store.dart';

class _FakeKeyStore implements ApiKeyStore {
  @override
  Future<String?> read() async => 'AIza_test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers each request with the next reply; records paths and bodies.
class _SeqAdapter implements HttpClientAdapter {
  _SeqAdapter(this.replies);

  final List<(int, Object)> replies;
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
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _ok(String text) => {
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

Map<String, Object?> _error(int code, String message, [String? status]) => {
      'error': {'code': code, 'message': message, 'status': ?status},
    };

const _messages = [LlmMessage.user('ahoj')];

(GeminiProvider, _SeqAdapter) _provider(
  List<(int, Object)> replies, {
  GeminiModelResolver? models,
}) {
  final adapter = _SeqAdapter(replies);
  final dio = Dio()..httpClientAdapter = adapter;
  return (GeminiProvider(_FakeKeyStore(), dio: dio, models: models), adapter);
}

DioException _dio(int status, Object body) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  group('pickGeminiModels', () {
    test('prefers the app ids when listed', () {
      final pair = pickGeminiModels(
          [kGeminiModel, kGeminiLiteModel, 'gemini-9-flash']);
      expect(pair!.main, kGeminiModel);
      expect(pair.lite, kGeminiLiteModel);
    });

    test('renamed: newest stable flash, previews and special models last', () {
      final pair = pickGeminiModels([
        'gemini-2.5-flash',
        'gemini-3-flash-preview',
        'gemini-3-flash',
        'gemini-3-flash-image',
        'gemini-3-flash-lite',
        'gemini-3-pro',
      ])!;
      expect(pair.main, 'gemini-3-flash');
      expect(pair.lite, 'gemini-3-flash-lite');
    });

    test('only a preview: it is used; no lite: lite = main', () {
      final pair = pickGeminiModels(['gemini-3-flash-preview'])!;
      expect(pair.main, 'gemini-3-flash-preview');
      expect(pair.lite, 'gemini-3-flash-preview');
    });

    test('a listed override wins, an unlisted one is ignored', () {
      expect(
          pickGeminiModels([kGeminiModel, 'gemini-2.5-flash'],
                  override: 'gemini-2.5-flash')!
              .main,
          'gemini-2.5-flash');
      expect(pickGeminiModels([kGeminiModel], override: 'gone')!.main,
          kGeminiModel);
    });

    test('no flash at all is null', () {
      expect(pickGeminiModels(['gemini-3-pro', 'text-embedding-004']), isNull);
    });

    test('selectable lists flash models newest first', () {
      expect(
        selectableGeminiModels(
            ['gemini-2.5-flash', 'gemini-3-flash', 'gemini-3-pro']),
        ['gemini-3-flash', 'gemini-2.5-flash'],
      );
    });
  });

  group('GeminiModelResolver', () {
    test('uses the constant until told otherwise; override applies to main',
        () async {
      final plain = GeminiModelResolver(listModels: () async => []);
      expect(await plain.resolve(kGeminiModel), kGeminiModel);

      final chosen = GeminiModelResolver(
          listModels: () async => [], override: () async => 'gemini-x-flash');
      expect(await chosen.resolve(kGeminiModel), 'gemini-x-flash');
      expect(await chosen.resolve(kGeminiLiteModel), kGeminiLiteModel);
    });

    test('reresolve lists, caches and maps both names', () async {
      var listed = 0;
      final r = GeminiModelResolver(listModels: () async {
        listed++;
        return ['gemini-3-flash', 'gemini-3-flash-lite'];
      });
      expect(await r.reresolve(kGeminiModel, kGeminiModel), 'gemini-3-flash');
      expect(await r.resolve(kGeminiLiteModel), 'gemini-3-flash-lite');
      expect(listed, 1);
      r.reset();
      expect(await r.resolve(kGeminiModel), kGeminiModel);
    });

    test('nothing better or a failed list is null', () async {
      final same =
          GeminiModelResolver(listModels: () async => [kGeminiModel]);
      expect(await same.reresolve(kGeminiModel, kGeminiModel), isNull);
      final broken =
          GeminiModelResolver(listModels: () async => throw StateError('x'));
      expect(await broken.reresolve(kGeminiModel, kGeminiModel), isNull);
    });
  });

  group('GeminiProvider repairs', () {
    test('a 404 re-resolves the model and retries once', () async {
      final resolver = GeminiModelResolver(
          listModels: () async => ['gemini-3-flash', 'gemini-3-flash-lite']);
      final (llm, adapter) = _provider([
        (404, _error(404, 'models/x is not found', 'NOT_FOUND')),
        (200, _ok('ano')),
      ], models: resolver);

      final result =
          await llm.generate(model: kGeminiModel, messages: _messages);
      expect(result.content, 'ano');
      expect(adapter.paths.first, contains(kGeminiModel));
      expect(adapter.paths.last, contains('gemini-3-flash:'));
    });

    test('a 404 with nothing better says the model is missing', () async {
      final resolver =
          GeminiModelResolver(listModels: () async => ['gemini-3-pro']);
      final (llm, adapter) = _provider([
        (404, _error(404, 'models/x is not found', 'NOT_FOUND')),
      ], models: resolver);
      await expectLater(
        llm.generate(model: kGeminiModel, messages: _messages),
        throwsA(isA<AiPermanentException>()
            .having((e) => e.kind, 'kind', GeminiErrorKind.modelMissing)),
      );
      expect(adapter.paths, hasLength(1));
    });

    test('a 400 about thinking drops thinkingConfig and remembers it',
        () async {
      final (llm, adapter) = _provider([
        (400, _error(400, 'Unknown name "thinkingConfig": Cannot find field.',
            'INVALID_ARGUMENT')),
        (200, _ok('a')),
        (200, _ok('b')),
      ]);
      await llm.generate(model: 'm', messages: _messages);
      await llm.generate(model: 'm', messages: _messages);

      Object? thinking(Map<String, Object?> body) =>
          (body['generationConfig'] as Map)['thinkingConfig'];
      expect(thinking(adapter.bodies[0]), isNotNull);
      expect(thinking(adapter.bodies[1]), isNull);
      expect(thinking(adapter.bodies[2]), isNull);
    });

    test('a 400 about the search tool retries without it, not grounded',
        () async {
      final (llm, adapter) = _provider([
        (400, _error(400, 'Search Grounding is not supported.',
            'INVALID_ARGUMENT')),
        (200, _ok('Božena Němcová')),
      ]);
      final result =
          await llm.generate(model: 'm', messages: _messages, search: true);
      expect(result.grounded, isFalse);
      expect(adapter.bodies[0]['tools'], isNotNull);
      expect(adapter.bodies[1]['tools'], isNull);
    });

    test('an unrelated 400 is not retried', () async {
      final (llm, adapter) = _provider([
        (400, _error(400, 'Request payload size exceeds the limit.',
            'INVALID_ARGUMENT')),
      ]);
      await expectLater(
        llm.generate(model: 'm', messages: _messages, search: true),
        throwsA(isA<AiPermanentException>()
            .having((e) => e.kind, 'kind', GeminiErrorKind.badRequest)),
      );
      expect(adapter.paths, hasLength(1));
    });
  });

  group('classifyGeminiFailure', () {
    final cases = <String, (int, Object, GeminiErrorKind, bool)>{
      'invalid key 400': (
        400,
        _error(400, 'API key not valid. Please pass a valid API key.',
            'INVALID_ARGUMENT'),
        GeminiErrorKind.badKey,
        false
      ),
      'api disabled 403': (
        403,
        _error(403, 'Generative Language API has not been used in project 1',
            'PERMISSION_DENIED'),
        GeminiErrorKind.apiDisabled,
        false
      ),
      'region 400': (
        400,
        _error(400, 'User location is not supported for the API use.',
            'FAILED_PRECONDITION'),
        GeminiErrorKind.region,
        false
      ),
      'model 404': (
        404,
        _error(404, 'models/x is not found', 'NOT_FOUND'),
        GeminiErrorKind.modelMissing,
        false
      ),
      'quota 429': (
        429,
        _error(429, 'Resource has been exhausted', 'RESOURCE_EXHAUSTED'),
        GeminiErrorKind.quota,
        true
      ),
      'server 503': (
        503,
        _error(503, 'The model is overloaded.', 'UNAVAILABLE'),
        GeminiErrorKind.overloaded,
        true
      ),
      'server 500': (
        500,
        _error(500, 'Internal error encountered.', 'INTERNAL'),
        GeminiErrorKind.network,
        true
      ),
    };
    cases.forEach((name, c) {
      test(name, () {
        final failure = classifyGeminiFailure(_dio(c.$1, c.$2));
        expect(failure.kind, c.$3);
        expect(failure.transient, c.$4);
        expect(failure.reason, isNotEmpty);
      });
    });

    test('a timeout is network and transient', () {
      final failure = classifyGeminiFailure(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.receiveTimeout,
      ));
      expect(failure.kind, GeminiErrorKind.network);
      expect(failure.transient, isTrue);
    });
  });

  group('geminiFailureText', () {
    test('a missing model is not called a bad key, and quotes Google', () {
      const e = AiPermanentException('x',
          statusCode: 404,
          kind: GeminiErrorKind.modelMissing,
          reason: 'models/gemini-3.5-flash is not found');
      final text = geminiFailureText(e);
      expect(text, contains('Model Gemini'));
      expect(text, isNot(contains('klíč neprošel')));
      expect(text, contains('(Google: models/gemini-3.5-flash is not found)'));
    });

    test('every kind has its own sentence', () {
      final texts = {
        for (final kind in GeminiErrorKind.values)
          geminiFailureText(AiPermanentException('x', kind: kind)),
      };
      expect(texts, hasLength(GeminiErrorKind.values.length));
    });
  });

  group('card lookup fallback', () {
    CardLookupService service(Object geminiReply, WebAnswer? web) =>
        CardLookupService(
          gemini: _ThrowingGemini(geminiReply),
          hasGeminiKey: () async => true,
          web: _Web(web),
        );

    test('a Gemini failure other than the key falls back to Groq, with why',
        () async {
      final found = await service(
        const AiPermanentException('x', kind: GeminiErrorKind.modelMissing),
        const WebAnswer(answer: 'Babička je novela.', sources: []),
      ).lookUp('Babička');
      expect(found.viaGemini, isFalse);
      expect(found.content, 'Babička je novela.');
      expect(found.geminiProblem, contains('Model Gemini'));
    });

    test('a bad key is shown, not papered over', () async {
      await expectLater(
        service(const AiPermanentException('x', kind: GeminiErrorKind.badKey),
                const WebAnswer(answer: 'y', sources: []))
            .lookUp('Babička'),
        throwsA(isA<AiException>()
            .having((e) => e.kind, 'kind', GeminiErrorKind.badKey)),
      );
    });

    test('both failing reports the Gemini reason', () async {
      await expectLater(
        service(const AiTransientException('x', kind: GeminiErrorKind.quota),
                null)
            .lookUp('Babička'),
        throwsA(isA<AiException>()
            .having((e) => e.kind, 'kind', GeminiErrorKind.quota)),
      );
    });
  });

  group('checkGeminiKey', () {
    test('all good: models picked, resolver primed, search grounded',
        () async {
      final resolver = GeminiModelResolver(listModels: () async => []);
      final gemini = _ThrowingGemini(
          const GeminiCompletion(content: 'ano'));
      final report = await checkGeminiKey(
        listModels: () async => ['gemini-3-flash', 'gemini-3-flash-lite'],
        gemini: gemini,
        resolver: resolver,
      );
      expect(report.works, isTrue);
      expect(report.steps.map((s) => s.state),
          everyElement(CheckState.ok));
      expect(report.models!.main, 'gemini-3-flash');
      expect(await resolver.resolve(kGeminiModel), 'gemini-3-flash');
      expect(report.selectable, ['gemini-3-flash', 'gemini-3-flash-lite']);
    });

    test('a bad key stops at the first step with its reason', () async {
      final report = await checkGeminiKey(
        listModels: () async => throw const AiPermanentException('x',
            kind: GeminiErrorKind.badKey, reason: 'API key not valid'),
        gemini: _ThrowingGemini('unused'),
        resolver: GeminiModelResolver(listModels: () async => []),
      );
      expect(report.works, isFalse);
      expect(report.steps.single.detail, contains('API key not valid'));
    });

    test('search refused is a warning, not a failure', () async {
      final report = await checkGeminiKey(
        listModels: () async => [kGeminiModel],
        gemini: _ThrowingGemini(
            const GeminiCompletion(content: 'x', grounded: false)),
        resolver: GeminiModelResolver(listModels: () async => []),
      );
      expect(report.works, isTrue);
      expect(report.steps.last.state, CheckState.warn);
    });
  });
}

class _ThrowingGemini extends GeminiProvider {
  _ThrowingGemini(this.reply) : super(_FakeKeyStore());

  final Object reply;

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
    final r = reply;
    if (r is Exception) throw r;
    if (r is GeminiCompletion) return r;
    return GeminiCompletion(content: '$r');
  }
}

class _Web implements WebAnswerService {
  _Web(this.answer);

  final WebAnswer? answer;

  @override
  Future<WebAnswer?> lookUp(String question) async => answer;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
