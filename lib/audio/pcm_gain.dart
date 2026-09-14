import 'dart:math' as math;
import 'dart:typed_data';

/// Where a normalised chunk's loudest sample lands: ~-1 dBFS, leaving a little
/// headroom so rounding can never wrap a sample around.
const double kNormalizePeakTarget = 0.89;

/// Below this a gain is not worth copying the chunk for.
const double _kMinUsefulGain = 1.1;

/// The gain that lifts the loudest sample in [frames] to
/// [kNormalizePeakTarget], capped at [maxGain].
///
/// Peak-based on purpose: it can never clip, whatever the chunk holds. The
/// cost is that one loud transient — a door, a cough into the phone — keeps
/// the rest of that chunk quiet, which is the safe direction to be wrong in.
///
/// Returns exactly 1 when there is nothing useful to do: [maxGain] of 1 or
/// less, digital silence, or a chunk already close to full scale.
double normalizingGain(List<Uint8List> frames, {required double maxGain}) {
  if (maxGain <= 1) return 1;

  var peak = 0;
  for (final frame in frames) {
    final data = ByteData.sublistView(frame);
    for (var i = 0; i + 1 < frame.length; i += 2) {
      final sample = data.getInt16(i, Endian.little).abs();
      if (sample > peak) peak = sample;
    }
  }
  if (peak == 0) return 1;

  final gain = math.min(maxGain, kNormalizePeakTarget * 32767 / peak);
  return gain < _kMinUsefulGain ? 1 : gain;
}

/// [frames] with every PCM16 sample multiplied by [gain], clamped to the
/// Int16 range. The input is not modified; a gain of exactly 1 returns it
/// as-is.
List<Uint8List> applyGain(List<Uint8List> frames, double gain) {
  if (gain == 1) return frames;
  return [for (final frame in frames) _scaled(frame, gain)];
}

Uint8List _scaled(Uint8List frame, double gain) {
  final out = Uint8List(frame.length);
  final src = ByteData.sublistView(frame);
  final dst = ByteData.sublistView(out);
  for (var i = 0; i + 1 < frame.length; i += 2) {
    final scaled = (src.getInt16(i, Endian.little) * gain).round();
    dst.setInt16(i, scaled.clamp(-32768, 32767), Endian.little);
  }
  // A dangling odd byte is not half a sample anyone can scale; keep it.
  if (frame.length.isOdd) out[frame.length - 1] = frame[frame.length - 1];
  return out;
}
