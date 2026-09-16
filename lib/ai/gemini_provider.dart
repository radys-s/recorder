import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/gemini_failure.dart';
import '../core/logging.dart';
import '../data/secure/api_key_store.dart';
import 'answer_source.dart';
import 'llm_provider.dart';

/// A picture sent along with the last user message.
///
/// Despite the name any inline file Gemini accepts fits here — [LlmMedia] is
/// the same class under the name to use for audio.
class LlmImage {
  const LlmImage(this.bytes, {this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;

  Map<String, Object?> toPart() => {
        'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
      };
}

/// Inline audio or any other file part, e.g. `LlmMedia(bytes, mimeType:
/// 'audio/wav')`. Sent through `images`, which go before the prompt text.
typedef LlmMedia = LlmImage;

/// A Gemini reply, with the pages Google Search grounded it on.
class GeminiCompletion {
  const GeminiCompletion({
    required this.content,
    this.sources = const [],
    this.truncated = false,
  });

  final String content;
  final List<AnswerSource> sources;

  /// The model hit `maxOutputTokens` but still produced some text.
  final bool truncated;
}

/// Google's Gemini API (`generateContent`), the optional second key.
///
/// It exists for what Groq cannot do on this account's free tier: pictures,
/// a context large enough for whole cards, and search grounding that does not
/// fight an 8 000-token-per-minute ceiling. Like the Groq providers, the key
/// is read per request, so a change in Settings applies to the next call.
class GeminiProvider extends LlmProvider {
  GeminiProvider(this._apiKeyStore, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 60),
                receiveTimeout: const Duration(seconds: 120),
                responseType: ResponseType.json,
              ),
            );

  static const _tag = 'ai.gemini';

  final ApiKeyStore _apiKeyStore;
  final Dio _dio;

  /// [temperature] is ignored on purpose: Google's guidance for Gemini 3 is to
  /// keep the default 1.0, and lower values are documented to cause looping.
  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    final result = await generate(
      model: model,
      messages: messages,
      maxTokens: maxTokens,
      jsonMode: jsonMode,
      timeout: timeout,
    );
    return LlmCompletion(content: result.content);
  }

  Future<GeminiCompletion> generate({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    bool search = false,
    bool jsonMode = false,
    int? maxTokens,
    Duration? timeout,
  }) async {
    final apiKey = await _apiKeyStore.read();
    if (apiKey == null) {
      throw const AiPermanentException(
        'Chybí Gemini klíč. Přidej ho v Nastavení.',
      );
    }

    try {
      final response = await _dio.post<Object?>(
        '$kGeminiBaseUrl/models/$model:generateContent',
        data: buildGeminiRequest(
          messages: messages,
          images: images,
          search: search,
          jsonMode: jsonMode,
          maxTokens: maxTokens,
        ),
        options: Options(
          headers: {'x-goog-api-key': apiKey},
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
      return parseGeminiResponse(response.data);
    } on DioException catch (e) {
      final failure = classifyGeminiFailure(e);
      if (failure.statusCode != null) {
        AppLog.e(_tag, 'HTTP ${failure.statusCode}: ${failure.message}');
        // Debug-only, like Groq's: the body can echo the prompt back.
        if (kDebugMode) AppLog.d(_tag, 'raw body: ${e.response?.data}');
      }
      throw failure.transient
          ? AiTransientException(failure.message,
              statusCode: failure.statusCode)
          : AiPermanentException(failure.message,
              statusCode: failure.statusCode);
    }
  }
}

/// The request body. System messages become `systemInstruction`, assistant
/// turns become `model` turns, and pictures go in front of the text of the
/// last user message — the order Google recommends for a single image prompt.
///
/// Thinking is kept low: reasoning tokens count against `maxOutputTokens`
/// (the M15 lesson again), and none of these calls needs deep reasoning.
Map<String, Object?> buildGeminiRequest({
  required List<LlmMessage> messages,
  List<LlmImage> images = const [],
  bool search = false,
  bool jsonMode = false,
  int? maxTokens,
}) {
  final system = [
    for (final m in messages)
      if (m.role == 'system' && m.content.trim().isNotEmpty) m.content.trim(),
  ].join('\n\n');
  final turns = [
    for (final m in messages)
      if (m.role != 'system') m,
  ];
  final lastUser = turns.lastIndexWhere((m) => m.role == 'user');

  return {
    if (system.isNotEmpty)
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
    'contents': [
      for (var i = 0; i < turns.length; i++)
        {
          'role': turns[i].role == 'assistant' ? 'model' : 'user',
          'parts': [
            if (i == lastUser)
              for (final image in images) image.toPart(),
            {'text': turns[i].content},
          ],
        },
      if (lastUser < 0 && images.isNotEmpty)
        {
          'role': 'user',
          'parts': [for (final image in images) image.toPart()],
        },
    ],
    if (search)
      'tools': [
        {'googleSearch': <String, Object?>{}},
      ],
    'generationConfig': {
      'maxOutputTokens': ?maxTokens,
      if (jsonMode) 'responseMimeType': 'application/json',
      'thinkingConfig': {'thinkingLevel': kGeminiThinkingLevel},
    },
  };
}

/// Reads a `generateContent` response. Every shape it does not expect is a
/// classified permanent failure, never a TypeError.
GeminiCompletion parseGeminiResponse(Object? data) {
  if (data is! Map) {
    throw AiPermanentException(
      'Unexpected response shape: ${data.runtimeType}',
    );
  }

  final feedback = data['promptFeedback'];
  final blocked = feedback is Map ? feedback['blockReason'] : null;
  if (blocked is String && blocked.isNotEmpty) {
    throw AiPermanentException('Gemini požadavek zablokoval ($blocked).');
  }

  final candidates = data['candidates'];
  final first =
      candidates is List && candidates.isNotEmpty ? candidates.first : null;
  if (first is! Map) {
    throw const AiPermanentException('Response carried no candidates.');
  }

  final content = first['content'];
  final parts = content is Map ? content['parts'] : null;
  // Thought summaries are marked `thought: true` and are not the answer.
  final text = [
    if (parts is List)
      for (final part in parts)
        if (part is Map && part['thought'] != true && part['text'] is String)
          part['text'] as String,
  ].join().trim();

  final finish = first['finishReason'];
  if (text.isEmpty) {
    throw AiPermanentException(
      finish == 'MAX_TOKENS'
          ? 'Odpověď se nevešla do limitu tokenů.'
          : 'Response carried no text (finishReason: $finish).',
    );
  }

  return GeminiCompletion(
    content: text,
    sources: groundingSources(first['groundingMetadata']),
    truncated: finish == 'MAX_TOKENS',
  );
}

/// The web pages a grounded answer used, de-duplicated by site and capped.
List<AnswerSource> groundingSources(
  Object? metadata, {
  int max = kMaxAnswerSources,
}) {
  final chunks = metadata is Map ? metadata['groundingChunks'] : null;
  if (chunks is! List) return const [];

  final found = <AnswerSource>[];
  for (final chunk in chunks) {
    final web = chunk is Map ? chunk['web'] : null;
    if (web is! Map) continue;
    final source =
        AnswerSource.tryParse({'url': web['uri'], 'title': web['title']});
    if (source == null || found.any((s) => s.domain == source.domain)) {
      continue;
    }
    found.add(source);
    if (found.length >= max) break;
  }
  return found;
}
