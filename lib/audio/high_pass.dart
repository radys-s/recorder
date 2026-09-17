import 'dart:math' as math;
import 'dart:typed_data';

import '../core/constants.dart';

/// Cut-off below which the recording is treated as rumble, not voice.
///
/// The lowest fundamental of a male speaking voice sits around 85 Hz, and
/// what makes speech intelligible lives far above that; below it is handling
/// noise, air conditioning, desk thumps and the microphone's DC offset. Those
/// carry a lot of energy, so left in they inflate every RMS level the chunker,
/// the calibrator and the gain decide on.
const double kHighPassCutoffHz = 80;

/// A second-order Butterworth high-pass filter over little-endian PCM16 mono.
///
/// Stateful across calls, so a stream split into arbitrary events is filtered
/// exactly as if it had arrived in one piece — including an event that ends
/// halfway through a sample, whose odd byte is carried into the next one.
class HighPassFilter {
  HighPassFilter({
    double cutoffHz = kHighPassCutoffHz,
    int sampleRate = kSampleRateHz,
  }) {
    const q = math.sqrt1_2;
    final w0 = 2 * math.pi * cutoffHz / sampleRate;
    final cos = math.cos(w0);
    final alpha = math.sin(w0) / (2 * q);
    final a0 = 1 + alpha;
    _b0 = (1 + cos) / 2 / a0;
    _b1 = -(1 + cos) / a0;
    _b2 = (1 + cos) / 2 / a0;
    _a1 = -2 * cos / a0;
    _a2 = (1 - alpha) / a0;
  }

  late final double _b0, _b1, _b2, _a1, _a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;
  int? _carry;

  /// Filters [bytes] and returns the whole samples it completes. A trailing
  /// odd byte is held back and comes out with the next call.
  Uint8List process(Uint8List bytes) {
    final carry = _carry;
    final total = bytes.length + (carry == null ? 0 : 1);
    final samples = total ~/ 2;
    final out = Uint8List(samples * 2);
    final view = ByteData.sublistView(out);

    var read = 0;
    int byteAt(int i) =>
        carry == null ? bytes[i] : (i == 0 ? carry : bytes[i - 1]);
    for (var s = 0; s < samples; s++) {
      final lo = byteAt(read);
      final hi = byteAt(read + 1);
      read += 2;
      final x = ((hi << 8) | lo).toSigned(16).toDouble();
      final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
      _x2 = _x1;
      _x1 = x;
      _y2 = _y1;
      _y1 = y;
      view.setInt16(s * 2, y.round().clamp(-32768, 32767), Endian.little);
    }
    _carry = total.isOdd ? byteAt(total - 1) : null;
    return out;
  }

  /// Forgets the previous samples, for a new recording.
  void reset() {
    _x1 = _x2 = _y1 = _y2 = 0;
    _carry = null;
  }
}
