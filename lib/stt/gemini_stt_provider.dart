import 'dart:io';

import '../ai/gemini_provider.dart';
import '../ai/llm_provider.dart';
import '../core/constants.dart';
import '../data/db/tables/preferences_table.dart';
import 'refined_transcriber.dart';
import 'stt_provider.dart';

/// Gemini listening to one live chunk — the last engine in the fallback
/// chain, used when both Whisper models are rate limited.
///
/// It sends the audio of the chunk to Google, the same as the refined pass
/// does, so it only runs when a Gemini key is set.
class GeminiSttProvider implements SttProvider {
  GeminiSttProvider(this._gemini);

  final GeminiProvider _gemini;

  @override
  Future<TranscriptionResult> transcribe({
    required File audioFile,
    String? promptContext,
    String? languageCode,
    MicSensitivity sensitivity = MicSensitivity.medium,
    String? glossary,
    double? noSpeechProbThreshold,
    double? lowAvgLogprobThreshold,
    Duration? timeout,
  }) async {
    if (!await audioFile.exists()) {
      throw SttPermanentException('Audio file is missing: ${audioFile.path}');
    }
    try {
      final result = await _gemini.generate(
        model: kGeminiLiteModel,
        messages: refinedGeminiMessages(
          RefinedContext(
            glossary: glossary,
            previousText: promptContext,
            languageCode: languageCode,
          ),
        ),
        images: [LlmMedia(await audioFile.readAsBytes(), mimeType: 'audio/wav')],
        maxTokens: 4000,
        timeout: timeout ?? kGeminiSttTimeout,
      );
      return TranscriptionResult(
        text: cleanGeminiTranscript(result.content),
        engine: 'gemini',
      );
    } on AiTransientException catch (e) {
      if (e.statusCode == 429) {
        throw SttRateLimited(
          e.message,
          retryAfter: e.retryAfter,
          statusCode: 429,
        );
      }
      throw SttTransientException(e.message, statusCode: e.statusCode);
    } on AiException catch (e) {
      throw SttPermanentException(e.message, statusCode: e.statusCode);
    }
  }
}
