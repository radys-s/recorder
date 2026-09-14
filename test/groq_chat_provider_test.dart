import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/groq_chat_provider.dart';
import 'package:recorder/ai/llm_provider.dart';
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

(GroqChatProvider, _Adapter) _provider(
  int status,
  Object body, {
  String? key = 'gsk_test',
}) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (GroqChatProvider(_FakeKeyStore(key), dio: dio), adapter);
}

Map<String, Object?> _reply(Object? content, {Object? tools}) => {
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'content': content,
            'executed_tools': ?tools,
          },
        },
      ],
    };

const _messages = [LlmMessage.system('Be brief.'), LlmMessage.user('Ahoj')];

void main() {
  test('no key is a permanent failure, and nothing is sent', () async {
    final (llm, adapter) = _provider(200, _reply('x'), key: null);
    await expectLater(
      llm.complete(model: 'm', messages: _messages),
      throwsA(isA<AiPermanentException>()),
    );
    expect(adapter.options, isNull);
  });

  test('sends the model, the messages, the key and the options asked for',
      () async {
    final (llm, adapter) = _provider(200, _reply('  {"a": 1}  '));
    final text = await llm.complete(
      model: 'openai/gpt-oss-120b',
      messages: _messages,
      temperature: 0.1,
      maxTokens: 300,
      jsonMode: true,
    );

    expect(text, '{"a": 1}');
    expect(adapter.options!.headers['Authorization'], 'Bearer gsk_test');
    expect(adapter.sent, {
      'model': 'openai/gpt-oss-120b',
      'messages': [
        {'role': 'system', 'content': 'Be brief.'},
        {'role': 'user', 'content': 'Ahoj'},
      ],
      'temperature': 0.1,
      'max_tokens': 300,
      'response_format': {'type': 'json_object'},
    });
  });

  test('leaves out max_tokens and response_format when not asked for',
      () async {
    final (llm, adapter) = _provider(200, _reply('ok'));
    await llm.complete(model: 'm', messages: _messages);
    expect(adapter.sent!.containsKey('max_tokens'), isFalse);
    expect(adapter.sent!.containsKey('response_format'), isFalse);
  });

  test('keeps the server-side tool calls for the web hop', () async {
    final tools = [
      {'type': 'search', 'output': '{"results": []}'},
    ];
    final (llm, _) = _provider(200, _reply('Sazba je 3,5 %.', tools: tools));
    final completion =
        await llm.completeDetailed(model: 'm', messages: _messages);
    expect(completion.content, 'Sazba je 3,5 %.');
    expect(completion.executedTools, hasLength(1));

    final (plain, _) = _provider(200, _reply('ok'));
    expect(
      (await plain.completeDetailed(model: 'm', messages: _messages))
          .executedTools,
      isEmpty,
    );
  });

  group('a malformed envelope is a classified failure, never a TypeError', () {
    final bodies = <String, Object>{
      'no choices': {'id': 'x'},
      'empty choices': {'choices': <Object>[]},
      'choice is not an object': {
        'choices': ['x'],
      },
      'content is not a string': _reply(5),
      'content missing': _reply(null),
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

  test('a rate limit is transient and keeps the wait Groq names', () async {
    final (llm, _) = _provider(429, {
      'error': {'message': 'Rate limit reached. Please try again in 9.4s.'},
    });
    await expectLater(
      llm.complete(model: 'm', messages: _messages),
      throwsA(
        isA<AiTransientException>()
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.message, 'message', contains('9.4s')),
      ),
    );
  });

  test('a retired model is permanent', () async {
    final (llm, _) = _provider(404, {
      'error': {'message': 'The model does not exist.'},
    });
    await expectLater(
      llm.complete(model: 'gone', messages: _messages),
      throwsA(
        isA<AiPermanentException>()
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });
}
