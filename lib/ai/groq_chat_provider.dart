import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/groq_failure.dart';
import '../core/logging.dart';
import '../data/secure/api_key_store.dart';
import 'llm_provider.dart';

/// Groq's OpenAI-compatible chat completions endpoint.
///
/// Like the Whisper provider, the key is read per request rather than cached,
/// so changing it in Settings takes effect on the very next call.
// `extends`, not `implements`: [LlmProvider.complete] carries a default body
// that unwraps [LlmProvider.completeDetailed], and only a subclass inherits it.
class GroqChatProvider extends LlmProvider {
  GroqChatProvider(this._apiKeyStore, {Dio? dio, this.reasoningEffort})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 60),
              // A full write-up of an hour-long meeting is a long generation;
              // individual calls shorten this via `timeout`.
              receiveTimeout: const Duration(seconds: 120),
              responseType: ResponseType.json,
            ),
          );

  static const _tag = 'ai.groq.chat';

  final ApiKeyStore _apiKeyStore;
  final Dio _dio;

  /// `reasoning_effort` for the gpt-oss models; null leaves Groq's default.
  /// Low keeps a small, frequent call from spending its budget thinking.
  final String? reasoningEffort;

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    final apiKey = await _apiKeyStore.read();
    if (apiKey == null) {
      throw const AiPermanentException(
        'No Groq API key configured. Add one in Settings.',
      );
    }

    try {
      final response = await _dio.post<Object?>(
        kGroqChatUrl,
        data: {
          'model': model,
          'messages': [for (final m in messages) m.toJson()],
          'temperature': temperature,
          'max_tokens': ?maxTokens,
          'reasoning_effort': ?reasoningEffort,
          if (jsonMode) 'response_format': {'type': 'json_object'},
        },
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
      return _parse(response.data);
    } on DioException catch (e) {
      throw _classify(e);
    }
  }

  LlmCompletion _parse(Object? data) {
    if (data is! Map) {
      throw AiPermanentException(
        'Unexpected response shape: ${data.runtimeType}',
      );
    }

    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiPermanentException('Response carried no choices.');
    }

    // Checked, not cast: a proxy or a changed envelope that puts anything but
    // an object here must surface as the classified failure below, not as a
    // TypeError that escapes the retry contract entirely.
    final first = choices.first;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String) {
      throw const AiPermanentException('Response is missing message content.');
    }

    // Only the agentic models ever set this; for everything else it is absent
    // and the list stays empty.
    final tools = message['executed_tools'];
    return LlmCompletion(
      content: content.trim(),
      executedTools: tools is List ? tools : const [],
    );
  }

  AiException _classify(DioException e) {
    final failure = classifyGroqFailure(e);
    if (failure.statusCode != null) {
      AppLog.e(
        _tag,
        'HTTP ${failure.statusCode} from Groq: ${failure.message}',
      );
      // Groq's own envelope names the real cause — which model, which ceiling,
      // how many tokens over. A gateway's bare reason phrase names none of it,
      // and telling the two apart is the difference between "raise a limit"
      // and "this request can never work". Debug-only: the body can carry the
      // prompt back, and that has no business in a release log.
      if (kDebugMode) {
        final body = e.response?.data;
        AppLog.d(_tag, 'raw body <${body.runtimeType}>: $body');
        final headers = e.response?.headers.map.entries
            .where((h) => h.key.startsWith('x-ratelimit'))
            .map((h) => '${h.key}=${h.value.join(',')}')
            .join(' ');
        if (headers != null && headers.isNotEmpty) {
          AppLog.d(_tag, 'rate limits: $headers');
        }
      }
    }
    return failure.transient
        ? AiTransientException(failure.message, statusCode: failure.statusCode)
        : AiPermanentException(failure.message, statusCode: failure.statusCode);
  }
}
