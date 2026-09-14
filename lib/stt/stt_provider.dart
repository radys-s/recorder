import 'dart:io';

import '../data/db/tables/preferences_table.dart';

/// What a provider gives back for one audio chunk.
class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    this.language,
    this.durationSeconds,
    this.droppedSegments = 0,
  });

  final String text;

  /// How many of the response's segments were discarded as likely silence or
  /// a decoding loop before [text] was assembled. See `filterWhisperSegments`.
  final int droppedSegments;

  /// Detected language, when the provider reports one.
  final String? language;

  /// Audio duration as measured by the provider — useful as a sanity check
  /// against the chunk length we think we uploaded.
  final double? durationSeconds;

  @override
  String toString() =>
      'TranscriptionResult(${text.length} chars, lang=$language, ${durationSeconds}s)';
}

/// Base class for STT failures. The split between [SttTransientException] and
/// [SttPermanentException] is the entire contract the retry worker needs: it
/// decides whether a queue row goes back in line or is parked for good.
abstract class SttException implements Exception {
  const SttException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      '$runtimeType($message${statusCode == null ? '' : ', HTTP $statusCode'})';
}

/// Retry later: rate limits, server errors, timeouts, no connectivity.
class SttTransientException extends SttException {
  const SttTransientException(super.message, {super.statusCode});
}

/// Do not retry: bad or missing API key, malformed request, rejected audio.
/// The UI is expected to surface these — retrying only burns quota.
class SttPermanentException extends SttException {
  const SttPermanentException(super.message, {super.statusCode});
}

/// Speech-to-text backend. Groq Whisper is the only implementation for now;
/// the interface exists so a second provider is a pure addition.
abstract class SttProvider {
  /// Transcribes a single audio file.
  ///
  /// [promptContext] is the tail of the previous chunk's transcript. Whisper
  /// treats it as the preceding text, which biases it towards continuing the
  /// same sentence across a chunk boundary — the mitigation for the accepted
  /// mid-word cuts.
  ///
  /// [sensitivity] decides how readily a segment the model scores as probable
  /// silence is still kept as quiet speech.
  Future<TranscriptionResult> transcribe({
    required File audioFile,
    String? promptContext,
    String? languageCode,
    MicSensitivity sensitivity = MicSensitivity.medium,
  });
}
