import 'dart:math' as math;
import 'dart:typed_data';

/// Running loudness measurement over a PCM16 little-endian stream.
///
/// Platform stream events are not guaranteed to be 2-byte aligned, so a
/// leftover odd byte is carried across events — otherwise every subsequent
/// sample would be read straddling two real samples and the level would be
/// garbage. The raw bytes themselves are unaffected by this; only the Int16
/// interpretation needs the care.
class PcmLevelMeter {
  int? _pendingByte;

  double _sumOfSquares = 0;
  int _sampleCount = 0;
  int _peakAbs = 0;

  /// Root-mean-square amplitude of everything seen since the last [reset],
  /// normalised to 0.0–1.0.
  double get rms {
    if (_sampleCount == 0) return 0;
    return math.sqrt(_sumOfSquares / _sampleCount) / 32768.0;
  }

  /// Loudest single sample since the last [reset], normalised to 0.0–1.0.
  double get peak => _peakAbs / 32768.0;

  int get sampleCount => _sampleCount;

  void addBytes(Uint8List bytes) {
    var offset = 0;

    // Pair a byte held back from the previous event with this event's first
    // byte to recover the sample that straddled the boundary.
    if (_pendingByte != null && bytes.isNotEmpty) {
      _addSample(_toInt16(_pendingByte!, bytes[0]));
      _pendingByte = null;
      offset = 1;
    }

    final usableLength = bytes.length - offset;
    final wholeSamples = usableLength ~/ 2;

    for (var i = 0; i < wholeSamples; i++) {
      final index = offset + i * 2;
      _addSample(_toInt16(bytes[index], bytes[index + 1]));
    }

    // Hold back a trailing unpaired byte for the next event.
    if (usableLength.isOdd) {
      _pendingByte = bytes[bytes.length - 1];
    }
  }

  void reset() {
    _sumOfSquares = 0;
    _sampleCount = 0;
    _peakAbs = 0;
    // Deliberately keeps _pendingByte: the byte stream itself is continuous
    // across a stats window, only the measurement window restarts.
  }

  void _addSample(int sample) {
    _sumOfSquares += sample * sample;
    _sampleCount++;
    final abs = sample.abs();
    if (abs > _peakAbs) _peakAbs = abs;
  }

  /// Little-endian signed 16-bit from two bytes.
  static int _toInt16(int low, int high) {
    final unsigned = low | (high << 8);
    return unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned;
  }
}
