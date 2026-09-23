import 'dart:typed_data';

/// A source of continuous PCM16 mono 16kHz audio.
///
/// Exists so the recording pipeline can be driven by something other than the
/// microphone during development — see [WavReplayAudioSource]. Everything
/// downstream (chunker, WAV writer, queue) is identical either way, which is
/// what makes a replay run a real test of the pipeline rather than a mock of
/// it.
abstract class PcmAudioSource {
  /// Whether the source may be used. The microphone asks the user; a file
  /// source has nothing to ask.
  Future<bool> ensurePermission();

  /// Starts producing audio and returns the byte stream.
  ///
  /// Events are *not* guaranteed to be 2-byte aligned, so any consumer doing
  /// Int16 math must carry a remainder byte across events.
  Future<Stream<Uint8List>> start();

  /// Temporarily stops delivering audio while keeping this source and its
  /// stream alive. A resumed source continues the same recording rather than
  /// starting a second one.
  Future<void> pause();

  /// Continues a source previously paused by [pause]. Safe to call when it is
  /// already running, so a double tap cannot create a second stream.
  Future<void> resume();

  /// Stops producing audio. Safe to call when not started.
  Future<void> stop();

  /// Releases the underlying resource. The source is unusable afterwards.
  Future<void> dispose();
}
