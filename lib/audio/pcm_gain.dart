import 'dart:math' as math;
import 'dart:typed_data';

/// Loudness the voiced part of a chunk is raised to: RMS ~-20 dBFS, where a
/// close speaker on a phone microphone sits and where Whisper's no-speech
/// scores stop penalising a quiet voice.
const double kSpeechRmsTarget = 0.1;

/// Where the soft limiter starts bending: samples above this fraction of full
/// scale are compressed towards full scale instead of being clipped.
const double kLimiterKnee = 0.7;

/// Below this a gain is not worth copying the chunk for.
const double _kMinUsefulGain = 1.1;

/// The gain that brings the *voiced* frames of a chunk to [kSpeechRmsTarget],
/// capped at [maxGain].
///
/// Loudness-based rather than peak-based: a peak-based gain let one door slam
/// or a cough into the phone keep a quiet teacher quiet for the whole chunk.
/// The level is the median RMS of the voiced frames — pauses and room tone
/// are excluded so they cannot drag it down and over-amplify the noise, and a
/// median rather than a mean so a few loud frames cannot drag it up either.
/// The peaks that now overshoot are handled by the soft limiter in
/// [applyGain].
///
/// [voiced] is per frame, index for index with [frames]; a shorter list
/// treats the missing frames as unvoiced. Returns exactly 1 when there is
/// nothing useful to do: [maxGain] of 1 or less, no voiced frame, or speech
/// that is already loud enough.
double speechGain(
  List<Uint8List> frames,
  List<bool> voiced, {
  required double maxGain,
}) {
  if (maxGain <= 1) return 1;

  final levels = <double>[];
  for (var f = 0; f < frames.length && f < voiced.length; f++) {
    if (voiced[f]) levels.add(_rms(frames[f]));
  }
  if (levels.isEmpty) return 1;
  levels.sort();
  final level = levels[levels.length ~/ 2];
  if (level <= 0) return 1;

  final gain = math.min(maxGain, kSpeechRmsTarget / level);
  return gain < _kMinUsefulGain ? 1 : gain;
}

double _rms(Uint8List frame) {
  final data = ByteData.sublistView(frame);
  final samples = frame.length ~/ 2;
  if (samples == 0) return 0;
  var sumOfSquares = 0.0;
  for (var i = 0; i < samples; i++) {
    final s = data.getInt16(i * 2, Endian.little);
    sumOfSquares += s * s;
  }
  return math.sqrt(sumOfSquares / samples) / 32768.0;
}

/// [frames] with every PCM16 sample multiplied by [gain] and passed through a
/// soft limiter, so a loud transient bends towards full scale rather than
/// clipping. The input is not modified; a gain of exactly 1 returns it as-is.
List<Uint8List> applyGain(List<Uint8List> frames, double gain) {
  if (gain == 1) return frames;
  return [for (final frame in frames) _scaled(frame, gain)];
}

/// Identity below [kLimiterKnee], a tanh curve above it that approaches but
/// never reaches full scale. Continuous with slope 1 at the knee, so quiet
/// and normal samples are not coloured at all.
double softLimit(double x) {
  final magnitude = x.abs();
  if (magnitude <= kLimiterKnee) return x;
  final headroom = 1 - kLimiterKnee;
  final limited =
      kLimiterKnee + headroom * _tanh((magnitude - kLimiterKnee) / headroom);
  return x < 0 ? -limited : limited;
}

double _tanh(double x) {
  final e2 = math.exp(-2 * x);
  return (1 - e2) / (1 + e2);
}

Uint8List _scaled(Uint8List frame, double gain) {
  final out = Uint8List(frame.length);
  final src = ByteData.sublistView(frame);
  final dst = ByteData.sublistView(out);
  for (var i = 0; i + 1 < frame.length; i += 2) {
    final x = src.getInt16(i, Endian.little) * gain / 32768.0;
    // Back out at 32767 so a limited peak is symmetrical and never wraps.
    final scaled = (softLimit(x) * 32767).round();
    dst.setInt16(i, scaled.clamp(-32768, 32767), Endian.little);
  }
  // A dangling odd byte is not half a sample anyone can scale; keep it.
  if (frame.length.isOdd) out[frame.length - 1] = frame[frame.length - 1];
  return out;
}
