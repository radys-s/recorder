import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/gemini_failure.dart';
import '../core/logging.dart';
import '../data/secure/api_key_store.dart';
import 'answer_source.dart';
import 'gemini_model_resolver.dart';
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
    this.grounded = true,
  });

  final String content;
  final List<AnswerSource> sources;

  /// The model hit `maxOutputTokens` but still produced some text.
  final bool truncated;

  /// False when search was asked for but the model refused the tool, so the
  /// answer comes from the model alone.
  final bool grounded;
}

/// Google's Gemini API (`generateContent`), the optional second key.
///
/// It exists for what Groq cannot do on this account's free tier: pictures,
/// a context large enough for whole cards, and search grounding that does not
/// fight an 8 000-token-per-minute ceiling. Like the Groq providers, the key
/// is read per request, so a change in Settings applies to the next call.
class GeminiProvider extends LlmProvider {
  GeminiProvider(this._apiKeyStore, {Dio? dio, this._models})
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
  final GeminiModelResolver? _models;

  /// Models that answered 400 to `thinkingConfig`; it is left out for them.
  final Set<String> _noThinking = {};

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
    CancelToken? cancelToken,
  }) async {
    final apiKey = await _apiKeyStore.read();
    if (apiKey == null) {
      throw const AiPermanentException(
        'Chybí Gemini klíč. Přidej ho v Nastavení.',
      );
    }

    var id = await _models?.resolve(model) ?? model;
    var withSearch = search;
    var searchDropped = false;
    var modelSwapped = false;

    // At most one repair of each kind: a model Google does not offer, a
    // thinking field the model does not take, a search tool it cannot use.
    for (var attempt = 0;; attempt++) {
      final thinking = !_noThinking.contains(id);
      try {
        final response = await _dio.post<Object?>(
          '$kGeminiBaseUrl/models/$id:generateContent',
          data: buildGeminiRequest(
            messages: messages,
            images: images,
            search: withSearch,
            jsonMode: jsonMode,
            maxTokens: maxTokens,
            thinking: thinking,
          ),
          options: Options(
            headers: {'x-goog-api-key': apiKey},
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
          cancelToken: cancelToken,
        );
        final result = parseGeminiResponse(response.data);
        return searchDropped
            ? GeminiCompletion(
                content: result.content,
                sources: result.sources,
                truncated: result.truncated,
                grounded: false,
              )
            : result;
      } on DioException catch (e) {
        final failure = classifyGeminiFailure(e);
        if (failure.statusCode != null) {
          AppLog.e(_tag, 'HTTP ${failure.statusCode} on $id: ${failure.message}');
          // A short excerpt in release too: without it a refusal on the phone
          // is undiagnosable. The key travels in a header, never in the body.
          AppLog.d(_tag, 'body: ${clipReason('${e.response?.data}', max: 300)}');
          if (kDebugMode) AppLog.d(_tag, 'raw body: ${e.response?.data}');
        }
        if (attempt < 3 && e.type != DioExceptionType.cancel) {
          final reason = (failure.reason ?? '').toLowerCase();
          if (failure.kind == GeminiErrorKind.modelMissing &&
              !modelSwapped &&
              _models != null) {
            modelSwapped = true;
            final next = await _models.reresolve(model, id);
            if (next != null) {
              id = next;
              continue;
            }
          }
          if (failure.kind == GeminiErrorKind.badRequest &&
              failure.statusCode == 400) {
            if (thinking && reason.contains('think')) {
              _noThinking.add(id);
              continue;
            }
            if (withSearch &&
                (reason.contains('search') ||
                    reason.contains('tool') ||
                    reason.contains('grounding'))) {
              withSearch = false;
              searchDropped = true;
              continue;
            }
          }
        }
        throw failure.transient
            ? AiTransientException(failure.message,
                statusCode: failure.statusCode,
                kind: failure.kind,
                reason: failure.reason)
            : AiPermanentException(failure.message,
                statusCode: failure.statusCode,
                kind: failure.kind,
                reason: failure.reason);
      }
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
  bool thinking = true,
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
      if (thinking) 'thinkingConfig': {'thinkingLevel': kGeminiThinkingLevel},
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
