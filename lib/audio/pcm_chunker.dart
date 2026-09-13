import 'dart:math' as math;
import 'dart:typed_data';

import '../core/constants.dart';

/// One finalized slice of the recording, ready to be WAV-wrapped and uploaded.
class PcmChunk {
  const PcmChunk({
    required this.sequence,
    required this.startMs,
    required this.endMs,
    required this.frames,
    required this.byteLength,
    required this.voicedMs,
  });

  /// 0-based position of this chunk within its meeting.
  final int sequence;

  /// Offset of the chunk within the meeting, derived from the byte count
  /// rather than the wall clock — the stream is a fixed bit rate, so byte
  /// position is the more accurate timeline.
  final int startMs;
  final int endMs;

  /// The chunk's PCM bytes, still split into the frames they arrived in, so
  /// the writer can stream them out without a second large allocation.
  final List<Uint8List> frames;
  final int byteLength;

  /// How much of the chunk is louder than [kVoicedRmsThreshold] — i.e. could
  /// be somebody talking. A chunk with next to none of it is room tone, and
  /// uploading room tone is how Whisper ends up inventing sentences.
  final int voicedMs;

  Duration get duration => Duration(milliseconds: endMs - startMs);

  @override
  String toString() =>
      'PcmChunk(seq=$sequence, ${startMs}ms..${endMs}ms, $byteLength bytes)';
}

/// Splits a continuous PCM16 stream into chunks at quiet points.
///
/// Cut policy, in priority order:
///  1. Never cut before [minDuration] — a pause right after the previous cut
///     would otherwise produce a string of tiny chunks.
///  2. Between [minDuration] and [targetDuration], cut only on a *sustained*
///     quiet run ([confidentSilenceDuration]), i.e. a real pause between
///     sentences rather than the gap between two words.
///  3. From [targetDuration] on, a single silent frame is enough.
///  4. At [hardCapDuration], cut regardless — this is what keeps chunk size
///     bounded in a room that never gets quiet enough to trip the threshold.
///
/// Memory stays flat no matter how long the meeting runs: only the current
/// in-progress chunk is buffered (~1MB at the hard cap).
class PcmChunker {
  PcmChunker({
    required this.onChunk,
    this.minDuration = kChunkMinDuration,
    this.targetDuration = kChunkTargetDuration,
    this.hardCapDuration = kChunkHardCapDuration,
    this.frameDuration = kSilenceFrameDuration,
    this.silenceRmsThreshold = kSilenceRmsThreshold,
    this.confidentSilenceDuration = kConfidentSilenceDuration,
    this.sampleRate = kSampleRateHz,
    this.channels = kChannels,
  })  : _bytesPerSecond = sampleRate * channels * (kBitsPerSample ~/ 8),
        _frameBytes =
            (sampleRate * channels * (kBitsPerSample ~/ 8) * frameDuration.inMilliseconds) ~/ 1000 {
    _frame = Uint8List(_frameBytes);
  }

  /// Called synchronously each time a chunk is finalized, including the tail
  /// emitted by [flush].
  final void Function(PcmChunk chunk) onChunk;

  final Duration minDuration;
  final Duration targetDuration;
  final Duration hardCapDuration;
  final Duration frameDuration;
  final double silenceRmsThreshold;
  final Duration confidentSilenceDuration;
  final int sampleRate;
  final int channels;

  final int _bytesPerSecond;
  final int _frameBytes;

  /// Frame under construction. Incoming stream events are not aligned to
  /// anything, so bytes are copied in until a whole frame is available; frame
  /// boundaries are therefore always at even byte offsets from the stream
  /// start, which keeps the Int16 maths valid without a separate carry byte.
  late Uint8List _frame;
  int _frameFill = 0;

  final List<Uint8List> _frames = [];
  int _bufferedBytes = 0;
  int _emittedBytes = 0;
  int _sequence = 0;
  int _silentRunMs = 0;
  int _voicedMs = 0;

  int get bufferedBytes => _bufferedBytes;
  Duration get bufferedDuration => Duration(milliseconds: _msForBytes(_bufferedBytes));
  int get nextSequence => _sequence;
  int get frameBytes => _frameBytes;

  /// Feeds one stream event. Chunks are delivered via [onChunk] as they close.
  void addBytes(Uint8List bytes) {
    var offset = 0;
    while (offset < bytes.length) {
      final take = math.min(_frameBytes - _frameFill, bytes.length - offset);
      _frame.setRange(_frameFill, _frameFill + take, bytes, offset);
      _frameFill += take;
      offset += take;

      if (_frameFill == _frameBytes) _completeFrame();
    }
  }

  /// Closes the recording, emitting whatever is buffered as a final (short)
  /// chunk. Emits nothing if there is no audio pending.
  void flush() {
    if (_frameFill > 0) {
      // Drop a dangling odd byte rather than write half a sample.
      final usable = _frameFill - (_frameFill % 2);
      if (usable > 0) {
        _frames.add(_frame.sublist(0, usable));
        _bufferedBytes += usable;
      }
      _frameFill = 0;
    }
    if (_bufferedBytes == 0) return;
    _emit();
  }

  /// Clears all state, including the sequence counter. Use between meetings.
  void reset() {
    _frames.clear();
    _frameFill = 0;
    _bufferedBytes = 0;
    _emittedBytes = 0;
    _sequence = 0;
    _silentRunMs = 0;
    _voicedMs = 0;
  }

  void _completeFrame() {
    final frame = _frame;
    _frame = Uint8List(_frameBytes);
    _frameFill = 0;

    _frames.add(frame);
    _bufferedBytes += frame.length;

    final rms = _rmsOf(frame);
    if (rms >= kVoicedRmsThreshold) _voicedMs += frameDuration.inMilliseconds;

    final isSilent = rms < silenceRmsThreshold;
    _silentRunMs = isSilent ? _silentRunMs + frameDuration.inMilliseconds : 0;

    final chunkMs = _msForBytes(_bufferedBytes);
    if (chunkMs >= hardCapDuration.inMilliseconds) {
      _emit();
      return;
    }
    if (chunkMs < minDuration.inMilliseconds || !isSilent) return;

    final requiredSilenceMs = chunkMs >= targetDuration.inMilliseconds
        ? frameDuration.inMilliseconds
        : confidentSilenceDuration.inMilliseconds;
    if (_silentRunMs >= requiredSilenceMs) _emit();
  }

  void _emit() {
    final chunk = PcmChunk(
      sequence: _sequence,
      startMs: _msForBytes(_emittedBytes),
      endMs: _msForBytes(_emittedBytes + _bufferedBytes),
      frames: List<Uint8List>.unmodifiable(_frames),
      byteLength: _bufferedBytes,
      voicedMs: _voicedMs,
    );

    _sequence++;
    _emittedBytes += _bufferedBytes;
    _frames.clear();
    _bufferedBytes = 0;
    _silentRunMs = 0;
    _voicedMs = 0;

    onChunk(chunk);
  }

  int _msForBytes(int bytes) => (bytes * 1000) ~/ _bytesPerSecond;

  double _rmsOf(Uint8List frame) {
    var sumOfSquares = 0.0;
    final sampleCount = frame.length ~/ 2;
    for (var i = 0; i < sampleCount; i++) {
      final unsigned = frame[i * 2] | (frame[i * 2 + 1] << 8);
      final sample = unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned;
      sumOfSquares += sample * sample;
    }
    if (sampleCount == 0) return 0;
    return math.sqrt(sumOfSquares / sampleCount) / 32768.0;
  }
}
