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
    this.voicedFrames = const [],
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

  /// How much of the chunk is louder than [PcmChunker.voicedRmsThreshold] — i.e. could
  /// be somebody talking. A chunk with next to none of it is room tone, and
  /// uploading room tone is how Whisper ends up inventing sentences.
  final int voicedMs;

  /// Per frame, index for index with [frames]: whether it counted as voiced.
  /// What the loudness gain averages over, so pauses do not drag it down.
  final List<bool> voicedFrames;

  Duration get duration => Duration(milliseconds: endMs - startMs);

  @override
  String toString() =>
      'PcmChunk(seq=$sequence, ${startMs}ms..${endMs}ms, $byteLength bytes)';
}

/// Splits a continuous PCM16 stream into chunks at quiet points.
///
/// Two kinds of quiet count. *Silence* is below the absolute
/// [silenceRmsThreshold]. A *dip* is relative: well under the level the
/// speaker has been talking at, above whatever noise the room makes. Somebody
/// talking without stopping in a noisy classroom never reaches silence, but
/// still dips between sentences — which is where a cut belongs.
///
/// Cut policy, in priority order:
///  1. Never cut before [minDuration] — a pause right after the previous cut
///     would otherwise produce a string of tiny chunks.
///  2. Between [minDuration] and [targetDuration], cut on a sustained silence
///     ([confidentSilenceDuration]) or a sentence-length dip
///     ([sentencePauseDuration]); the gap between two words is shorter.
///  3. From [targetDuration] on, one silent frame or a short dip
///     ([shortPauseDuration]) is enough.
///  4. At [hardCapDuration] the chunk is closed at the quietest point of its
///     last [cutLookback] rather than mid-word, and the audio after that point
///     starts the next chunk. Only a signal with no dip at all is cut at the
///     cap itself.
///
/// Every cut splits the byte stream without dropping or repeating anything,
/// so the timeline stays gapless. Memory stays flat no matter how long the
/// meeting runs: only the current in-progress chunk is buffered (~1MB at the
/// hard cap).
class PcmChunker {
  PcmChunker({
    required this.onChunk,
    this.onFrameLevel,
    this.minDuration = kChunkMinDuration,
    this.targetDuration = kChunkTargetDuration,
    this.hardCapDuration = kChunkHardCapDuration,
    this.frameDuration = kSilenceFrameDuration,
    this.silenceRmsThreshold = kSilenceRmsThreshold,
    this.voicedRmsThreshold = kVoicedRmsThreshold,
    this.confidentSilenceDuration = kConfidentSilenceDuration,
    this.sentencePauseDuration = kSentencePauseDuration,
    this.shortPauseDuration = kShortPauseDuration,
    this.cutLookback = kCutLookbackDuration,
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

  /// Every completed frame's normalised RMS, for level calibration.
  final void Function(double rms)? onFrameLevel;

  final Duration minDuration;
  final Duration targetDuration;
  final Duration hardCapDuration;
  final Duration frameDuration;

  /// The two level thresholds are the only settings that may change while a
  /// recording runs: the sensitivity setting moves them, and a threshold that
  /// changes between two frames puts no seam in the audio. Each new value
  /// applies from the next completed frame.
  double silenceRmsThreshold;
  double voicedRmsThreshold;

  final Duration confidentSilenceDuration;
  final Duration sentencePauseDuration;
  final Duration shortPauseDuration;
  final Duration cutLookback;
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

  /// The buffered frames and, index for index, their level and whether they
  /// counted as voiced when they arrived.
  final List<Uint8List> _frames = [];
  final List<double> _levels = [];
  final List<bool> _voiced = [];
  int _bufferedBytes = 0;
  int _emittedBytes = 0;
  int _sequence = 0;
  int _silentRunMs = 0;
  int _dipRunMs = 0;

  /// Slowly rising minimum: the room's noise.
  double? _noiseFloor;

  /// Average level of the frames that sounded like speech.
  double _speechLevel = 0;

  int get bufferedBytes => _bufferedBytes;
  Duration get bufferedDuration => Duration(milliseconds: _msForBytes(_bufferedBytes));
  int get nextSequence => _sequence;
  int get frameBytes => _frameBytes;

  /// Below this a frame is a dip. Zero until speech has been heard, and never
  /// above half the speech level, so a room as loud as its speaker does not
  /// turn every frame into a pause.
  double get dipLevel {
    if (_speechLevel <= 0) return 0;
    final floor = _noiseFloor ?? 0;
    return math.min(
      math.max(floor * 2, _speechLevel * 0.3),
      _speechLevel * 0.5,
    );
  }

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
        _levels.add(0);
        _voiced.add(false);
        _bufferedBytes += usable;
      }
      _frameFill = 0;
    }
    if (_bufferedBytes == 0) return;
    _emit(_frames.length);
  }

  /// Closes the current chunk now, mid-recording — „Odpověz teď" wants the
  /// last few seconds transcribed without waiting for a pause.
  ///
  /// Unlike [flush] this keeps the partial frame under construction: only
  /// whole frames go out, so the next chunk starts on exactly the byte this
  /// one ended on and the timeline stays gapless. Returns whether a chunk was
  /// emitted.
  bool cut() {
    if (_bufferedBytes == 0) return false;
    _emit(_frames.length);
    return true;
  }

  /// Clears all state, including the sequence counter. Use between meetings.
  void reset() {
    _frames.clear();
    _levels.clear();
    _voiced.clear();
    _frameFill = 0;
    _bufferedBytes = 0;
    _emittedBytes = 0;
    _sequence = 0;
    _silentRunMs = 0;
    _dipRunMs = 0;
    _noiseFloor = null;
    _speechLevel = 0;
  }

  void _completeFrame() {
    final frame = _frame;
    _frame = Uint8List(_frameBytes);
    _frameFill = 0;

    final rms = _rmsOf(frame);
    onFrameLevel?.call(rms);
    final frameMs = frameDuration.inMilliseconds;

    // Judged against the levels before this frame, so a frame cannot pull the
    // bar towards itself.
    final isSilent = rms < silenceRmsThreshold;
    final isDip = isSilent || rms < dipLevel;
    _track(rms);

    _frames.add(frame);
    _levels.add(rms);
    _voiced.add(rms >= voicedRmsThreshold);
    _bufferedBytes += frame.length;

    _silentRunMs = isSilent ? _silentRunMs + frameMs : 0;
    _dipRunMs = isDip ? _dipRunMs + frameMs : 0;

    final chunkMs = _msForBytes(_bufferedBytes);
    if (chunkMs >= hardCapDuration.inMilliseconds) {
      _emit(_quietestCut());
      return;
    }
    if (chunkMs < minDuration.inMilliseconds || !isDip) return;

    final pastTarget = chunkMs >= targetDuration.inMilliseconds;
    final silenceEnough = _silentRunMs >=
        (pastTarget ? frameMs : confidentSilenceDuration.inMilliseconds);
    // A run of nothing but silence is the silence rule's to judge; the dip
    // rule is for the pause that never gets that quiet.
    final dipEnough = _dipRunMs > _silentRunMs &&
        _dipRunMs >=
            (pastTarget ? shortPauseDuration : sentencePauseDuration)
                .inMilliseconds;
    if (silenceEnough || dipEnough) _emit(_frames.length);
  }

  void _track(double rms) {
    final floor = _noiseFloor;
    // Falls at once, rises over ~20 s: a pause resets it, speech barely moves
    // it.
    _noiseFloor = floor == null || rms < floor ? rms : floor + (rms - floor) * 0.005;
    if (rms >= voicedRmsThreshold && rms >= silenceRmsThreshold) {
      _speechLevel = _speechLevel == 0 ? rms : _speechLevel * 0.95 + rms * 0.05;
    }
  }

  /// How many frames the chunk closed at the cap keeps: up to and including
  /// the quietest frame of the lookback window, or all of them when that
  /// window has no real dip to cut in.
  int _quietestCut() {
    final frameMs = frameDuration.inMilliseconds;
    final count = _frames.length;
    final minFrames = minDuration.inMilliseconds ~/ frameMs;
    final start = math.max(minFrames, count - cutLookback.inMilliseconds ~/ frameMs);
    if (start >= count - 1) return count;

    var best = count - 1;
    var sum = 0.0;
    for (var i = start; i < count; i++) {
      sum += _levels[i];
      // `<=` keeps the latest of equally quiet frames.
      if (_levels[i] <= _levels[best]) best = i;
    }
    final mean = sum / (count - start);
    if (_levels[best] >= mean * 0.8) return count;
    return best + 1;
  }

  /// Emits the first [count] buffered frames; the rest start the next chunk.
  void _emit(int count) {
    final head = _frames.sublist(0, count);
    final headBytes = head.fold<int>(0, (sum, f) => sum + f.length);
    final voicedFlags = List<bool>.unmodifiable(_voiced.take(count));
    final voicedFrames = voicedFlags.where((v) => v).length;

    final chunk = PcmChunk(
      sequence: _sequence,
      startMs: _msForBytes(_emittedBytes),
      endMs: _msForBytes(_emittedBytes + headBytes),
      frames: List<Uint8List>.unmodifiable(head),
      byteLength: headBytes,
      voicedMs: voicedFrames * frameDuration.inMilliseconds,
      voicedFrames: voicedFlags,
    );

    _sequence++;
    _emittedBytes += headBytes;
    _bufferedBytes -= headBytes;
    _frames.removeRange(0, count);
    _levels.removeRange(0, count);
    _voiced.removeRange(0, count);
    _silentRunMs = 0;
    _dipRunMs = 0;

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
