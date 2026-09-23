import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import 'pcm_audio_source.dart';

/// Thrown when the user denied microphone access. The caller decides how to
/// surface this (a banner, a dialog, a link to app settings).
class MicrophonePermissionDeniedException implements Exception {
  const MicrophonePermissionDeniedException();

  @override
  String toString() => 'MicrophonePermissionDeniedException';
}

/// Owns the microphone and exposes one continuous PCM16 stream per recording.
///
/// The stream is deliberately never stopped and restarted between chunks —
/// chunk boundaries are decided downstream by the chunker, so that no audio is
/// lost in the gap a stop/start would create.
class AudioCaptureService implements PcmAudioSource {
  AudioCaptureService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  static const _tag = 'audio.capture';

  bool _isCapturing = false;
  bool _isPaused = false;
  bool get isCapturing => _isCapturing;

  /// Asks for microphone access, requesting it from the user if not yet
  /// granted. Returns whether we ended up with permission.
  @override
  Future<bool> ensurePermission() => _recorder.hasPermission();

  /// Starts capturing and returns the raw PCM16 mono 16kHz byte stream.
  ///
  /// Stream events are *not* guaranteed to be 2-byte aligned, so any consumer
  /// doing Int16 math must carry a remainder byte across events.
  @override
  Future<Stream<Uint8List>> start() async {
    if (_isCapturing) {
      throw StateError('AudioCaptureService is already capturing');
    }

    if (!await ensurePermission()) {
      throw const MicrophonePermissionDeniedException();
    }

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: kSampleRateHz,
      numChannels: kChannels,
      // Leave the signal as untouched as possible: these processors change
      // gain in ways that would skew the chunker's RMS silence detection.
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      // What happens when a phone call arrives mid-meeting. The default is
      // `pause`, which on iOS stops the `AVAudioEngine` and waits for somebody
      // to resume it by hand — and nobody would: the stream neither closes nor
      // errors, so `RecordingController` never learns anything happened and the
      // meeting goes on "recording" silence until the user stops it. Resuming
      // automatically is the only behaviour that degrades to a gap in the audio
      // rather than to a lost second half.
      audioInterruption: AudioInterruptionMode.pauseResume,
    );

    final stream = await _recorder.startStream(config);
    _isCapturing = true;
    _isPaused = false;
    AppLog.d(
      _tag,
      'capture started (${kSampleRateHz}Hz, $kChannels ch, PCM16)',
    );

    return stream;
  }

  @override
  Future<void> pause() async {
    if (!_isCapturing || _isPaused) return;
    await _recorder.pause();
    _isPaused = true;
    AppLog.d(_tag, 'capture paused');
  }

  @override
  Future<void> resume() async {
    if (!_isCapturing || !_isPaused) return;
    await _recorder.resume();
    _isPaused = false;
    AppLog.d(_tag, 'capture resumed');
  }

  /// Stops the microphone. Safe to call when not capturing.
  @override
  Future<void> stop() async {
    if (!_isCapturing) return;

    await _recorder.stop();
    _isCapturing = false;
    _isPaused = false;
    AppLog.d(_tag, 'capture stopped');
  }

  /// Releases the underlying platform recorder. The service is unusable after
  /// this call.
  @override
  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
