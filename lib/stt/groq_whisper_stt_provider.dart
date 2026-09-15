import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/groq_failure.dart';
import '../core/logging.dart';
import '../core/sensitivity.dart';
import '../data/db/tables/preferences_table.dart';
import '../data/secure/api_key_store.dart';
import 'stt_provider.dart';
import 'whisper_segment_filter.dart';

/// Groq's OpenAI-compatible Whisper endpoint.
///
/// The key is read per request rather than cached, so changing it in Settings
/// takes effect on the very next chunk without restarting anything.
class GroqWhisperSttProvider implements SttProvider {
  GroqWhisperSttProvider(this._apiKeyStore, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                // Generous: a 30s chunk on a bad connection still deserves a
                // chance before we burn a retry attempt on it.
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 60),
                receiveTimeout: const Duration(seconds: 60),
                responseType: ResponseType.json,
              ),
            );

  static const _tag = 'stt.groq';

  /// How much of the previous transcript to hand Whisper as context. Long
  /// prompts start steering the output rather than just continuing it.
  static const _maxPromptChars = 200;

  final ApiKeyStore _apiKeyStore;
  final Dio _dio;

  @override
  Future<TranscriptionResult> transcribe({
    required File audioFile,
    String? promptContext,
    String? languageCode,
    MicSensitivity sensitivity = MicSensitivity.medium,
    String? glossary,
  }) async {
    final apiKey = await _apiKeyStore.read();
    if (apiKey == null) {
      throw const SttPermanentException(
        'No Groq API key configured. Add one in Settings.',
      );
    }

    if (!await audioFile.exists()) {
      throw SttPermanentException('Audio file is missing: ${audioFile.path}');
    }

    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFile.path,
        filename: p.basename(audioFile.path),
        contentType: DioMediaType('audio', 'wav'),
      ),
      'model': kGroqWhisperModel,
      // verbose_json also returns the detected language and duration, which
      // are worth having for diagnostics and cost nothing extra.
      'response_format': 'verbose_json',
      // Start from greedy decoding. Whisper still falls back to sampling at a
      // higher temperature for a segment it decodes badly — that is the API's
      // own behaviour and cannot be switched off here — but starting at zero
      // keeps the common case deterministic, and the segment filter catches
      // what the fallback invents.
      'temperature': '0',
      'language': ?languageCode,
      'prompt': ?whisperPrompt(glossary: glossary, context: promptContext),
    });

    try {
      final response = await _dio.post<Object?>(
        kGroqTranscriptionUrl,
        data: form,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );
      return _parse(response.data, SensitivityProfile.of(sensitivity));
    } on DioException catch (e) {
      throw _classify(e);
    }
  }

  /// The lesson's glossary first, then the tail of the previous chunk — the
  /// tail last, because Whisper continues from the end of its prompt.
  static String? whisperPrompt({String? glossary, String? context}) {
    final trimmed = context?.trim() ?? '';
    final tail = trimmed.length <= _maxPromptChars
        ? trimmed
        : trimmed.substring(trimmed.length - _maxPromptChars);
    final terms = glossary?.trim() ?? '';
    final prompt = [
      if (terms.isNotEmpty) terms.endsWith('.') ? terms : '$terms.',
      if (tail.isNotEmpty) tail,
    ].join(' ');
    return prompt.isEmpty ? null : prompt;
  }

  TranscriptionResult _parse(Object? data, SensitivityProfile profile) {
    if (data is! Map) {
      throw SttPermanentException(
        'Unexpected response shape: ${data.runtimeType}',
      );
    }
    final text = data['text'];
    if (text is! String) {
      throw const SttPermanentException('Response is missing a "text" field.');
    }

    // Segments Whisper itself scored as silence or a runaway loop are cut out
    // here, before the text goes anywhere — the transcript, live answers or
    // the notes.
    final filtered = filterWhisperSegments(
      data['segments'],
      noSpeechProbThreshold: profile.noSpeechProbThreshold,
      lowAvgLogprobThreshold: profile.lowAvgLogprobThreshold,
    );
    final kept = filtered != null && filtered.dropped > 0
        ? filtered.text
        : text.trim();

    final duration = data['duration'];
    return TranscriptionResult(
      text: kept,
      droppedSegments: filtered?.dropped ?? 0,
      language: data['language'] is String ? data['language'] as String : null,
      durationSeconds: duration is num ? duration.toDouble() : null,
    );
  }

  /// Maps a transport/HTTP failure onto the STT retry contract. The decision
  /// itself is shared with the chat endpoint — see [classifyGroqFailure].
  SttException _classify(DioException e) {
    final failure = classifyGroqFailure(e);
    if (failure.statusCode != null) {
      AppLog.e(_tag, 'HTTP ${failure.statusCode} from Groq: ${failure.message}');
    }
    return failure.transient
        ? SttTransientException(failure.message, statusCode: failure.statusCode)
        : SttPermanentException(failure.message, statusCode: failure.statusCode);
  }
}
