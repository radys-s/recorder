import 'package:dio/dio.dart' show CancelToken;

import 'ai_router.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';

/// Gemini for pictures, with Mistral's vision models behind it.
///
/// Every photo feature (timetable, board, card pages) talks to Gemini
/// directly, so the fallback sits here rather than in each service: when
/// Gemini is busy, out of quota or has no key, the same request goes to the
/// router's vision tier. Audio and PDF stay Gemini-only — Mistral's chat
/// endpoint does not take them — and so do search requests.
class GeminiWithVisionFallback extends GeminiProvider {
  GeminiWithVisionFallback(
    super.apiKeyStore, {
    required this.router,
    super.models,
    super.health,
    super.dio,
    super.overloadDelay,
  });

  final RoutedLlmProvider router;

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
    try {
      return await super.generate(
        model: model,
        messages: messages,
        images: images,
        search: search,
        jsonMode: jsonMode,
        maxTokens: maxTokens,
        timeout: timeout,
        cancelToken: cancelToken,
      );
    } on AiException catch (original, stack) {
      final picturesOnly =
          images.isNotEmpty &&
          images.every((i) => i.mimeType.startsWith('image/'));
      if (!picturesOnly ||
          search ||
          cancelToken?.isCancelled == true ||
          !await router.hasVisionRoute()) {
        rethrow;
      }
      try {
        final result = await router.completeVision(
          messages: messages,
          images: images,
          maxTokens: maxTokens,
          jsonMode: jsonMode,
          timeout: timeout,
        );
        return GeminiCompletion(content: result.content);
      } on AiException {
        // Without a Gemini key the fallback's own reason is the useful one;
        // otherwise Gemini's error names what the user can fix.
        if (original.message.startsWith('Chybí Gemini klíč')) rethrow;
        Error.throwWithStackTrace(original, stack);
      }
    }
  }
}
