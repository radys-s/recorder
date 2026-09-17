import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/groq_failure.dart';
import '../core/logging.dart';
import '../data/secure/api_key_store.dart';
import 'gemini_provider.dart' show LlmImage;
import 'llm_provider.dart';

/// Any service speaking OpenAI's `/chat/completions`: Groq, Mistral, Cerebras,
/// or a school's own model.
///
/// One class instead of one per vendor — they differ only in the address, the
/// key and the model ids, and the error envelope is the same everywhere.
/// The key is read per request, so a change in Settings applies at once.
class OpenAiCompatibleProvider extends LlmProvider {
  OpenAiCompatibleProvider(
    this._apiKeyStore, {
    required this.vendor,
    required this.baseUrl,
    this.missingKeyMessage,
    Dio? dio,
    this.reasoningEffort,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 60),
               // A full write-up of an hour-long lesson is a long generation;
               // individual calls shorten this via `timeout`.
               receiveTimeout: const Duration(seconds: 120),
               responseType: ResponseType.json,
             ),
           );

  /// Human name used in logs and error messages („Mistral").
  final String vendor;

  final ApiKeyStore _apiKeyStore;

  /// Read per request, so a custom address typed in Settings applies at once.
  final Future<String?> Function() baseUrl;
  final Dio _dio;

  /// Shown when no key is stored.
  final String? missingKeyMessage;

  /// `reasoning_effort` for gpt-oss models; null leaves the service default.
  final String? reasoningEffort;

  ApiKeyStore get keyStore => _apiKeyStore;

  String get _tag => 'ai.${vendor.toLowerCase()}.chat';

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) => completeWithImages(
    model: model,
    messages: messages,
    temperature: temperature,
    maxTokens: maxTokens,
    jsonMode: jsonMode,
    timeout: timeout,
  );

  /// Like [completeDetailed], with pictures put in front of the last user
  /// message's text as `image_url` data URIs.
  Future<LlmCompletion> completeWithImages({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    final apiKey = await _apiKeyStore.read();
    if (apiKey == null) {
      throw AiPermanentException(
        missingKeyMessage ?? 'Chybí $vendor klíč. Přidej ho v Nastavení.',
      );
    }
    final base = (await baseUrl())?.trim();
    if (base == null || base.isEmpty) {
      throw AiPermanentException('Chybí adresa služby $vendor.');
    }

    try {
      final response = await _dio.post<Object?>(
        chatCompletionsUrl(base),
        data: {
          'model': model,
          'messages': buildOpenAiMessages(messages, images),
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
      return parseOpenAiCompletion(response.data);
    } on DioException catch (e) {
      throw _classify(e);
    }
  }

  AiException _classify(DioException e) {
    final failure = classifyGroqFailure(e, vendor: vendor);
    final retryAfter = parseRetryAfter(
      e.response?.headers.value('retry-after'),
    );
    if (failure.statusCode != null) {
      AppLog.e(
        _tag,
        'HTTP ${failure.statusCode} from $vendor: ${failure.message}',
      );
      // The service's own envelope names the real cause — which model, which
      // ceiling. Debug-only: the body can carry the prompt back.
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
        ? AiTransientException(
            failure.message,
            statusCode: failure.statusCode,
            retryAfter: retryAfter,
          )
        : AiPermanentException(failure.message, statusCode: failure.statusCode);
  }
}

/// `https://x/v1` → `https://x/v1/chat/completions`; a full address is kept.
String chatCompletionsUrl(String base) {
  var url = base.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url.endsWith('/chat/completions') ? url : '$url/chat/completions';
}

/// Messages in OpenAI's shape; [images] join the last user message.
List<Map<String, Object?>> buildOpenAiMessages(
  List<LlmMessage> messages,
  List<LlmImage> images,
) {
  final lastUser = images.isEmpty
      ? -1
      : messages.lastIndexWhere((m) => m.role == 'user');
  return [
    for (var i = 0; i < messages.length; i++)
      if (i == lastUser)
        {
          'role': 'user',
          'content': [
            for (final image in images)
              {
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
                },
              },
            {'type': 'text', 'text': messages[i].content},
          ],
        }
      else
        messages[i].toJson(),
    if (lastUser == -1 && images.isNotEmpty)
      {
        'role': 'user',
        'content': [
          for (final image in images)
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
              },
            },
        ],
      },
  ];
}

/// Reads a `/chat/completions` response; every unexpected shape is permanent.
LlmCompletion parseOpenAiCompletion(Object? data) {
  if (data is! Map) {
    throw AiPermanentException(
      'Unexpected response shape: ${data.runtimeType}',
    );
  }
  final choices = data['choices'];
  if (choices is! List || choices.isEmpty) {
    throw const AiPermanentException('Response carried no choices.');
  }
  // Checked, not cast: a proxy or a changed envelope must surface as a
  // classified failure, not as a TypeError that escapes the retry contract.
  final first = choices.first;
  final message = first is Map ? first['message'] : null;
  final raw = message is Map ? message['content'] : null;
  // Mistral may answer with a list of content chunks.
  final content = raw is List
      ? raw
            .map(
              (c) => c is Map && c['text'] is String ? c['text'] as String : '',
            )
            .join()
      : raw;
  if (content is! String) {
    throw const AiPermanentException('Response is missing message content.');
  }
  // Only Groq's agentic models set this.
  final tools = message is Map ? message['executed_tools'] : null;
  return LlmCompletion(
    content: content.trim(),
    executedTools: tools is List ? tools : const [],
  );
}

/// `retry-after` in seconds (the only form these services send); null when
/// absent or unreadable.
Duration? parseRetryAfter(String? header) {
  final seconds = double.tryParse(header?.trim() ?? '');
  if (seconds == null || seconds < 0) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

/// The model ids a key can use at `{base}/models`, sorted. Same envelope for
/// every OpenAI-compatible service; the key stays on the device.
Future<List<String>> listOpenAiModels(
  ApiKeyStore keyStore, {
  required String vendor,
  required String baseUrl,
  Dio? dio,
}) async {
  final apiKey = await keyStore.read();
  if (apiKey == null) {
    throw AiPermanentException('Chybí $vendor klíč. Přidej ho v Nastavení.');
  }
  var base = baseUrl.trim();
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  if (base.endsWith('/chat/completions')) {
    base = base.substring(0, base.length - '/chat/completions'.length);
  }
  final client =
      dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          responseType: ResponseType.json,
        ),
      );
  try {
    final response = await client.get<Object?>(
      '$base/models',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );
    final data = response.data;
    final list = data is Map ? data['data'] : null;
    if (list is! List) {
      throw const AiPermanentException('Response carried no model list.');
    }
    return [
      for (final entry in list)
        if (entry is Map && entry['id'] is String) entry['id'] as String,
    ]..sort();
  } on DioException catch (e) {
    final failure = classifyGroqFailure(e, vendor: vendor);
    throw failure.transient
        ? AiTransientException(failure.message, statusCode: failure.statusCode)
        : AiPermanentException(failure.message, statusCode: failure.statusCode);
  }
}
