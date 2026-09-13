import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/pcm_stats.dart';

/// Encodes signed 16-bit samples as little-endian bytes, the way the platform
/// mic stream delivers them.
Uint8List pcm16(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final view = ByteData.view(bytes.buffer);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

void main() {
  group('PcmLevelMeter', () {
    test('reports zero for an untouched meter', () {
      final meter = PcmLevelMeter();
      expect(meter.rms, 0);
      expect(meter.peak, 0);
      expect(meter.sampleCount, 0);
    });

    test('reads little-endian samples and tracks peak', () {
      final meter = PcmLevelMeter()..addBytes(pcm16([0, 16384, -32768, 100]));

      expect(meter.sampleCount, 4);
      expect(meter.peak, 1.0); // -32768 is full scale
    });

    test('computes rms of a constant signal', () {
      final meter = PcmLevelMeter()..addBytes(pcm16([16384, -16384, 16384, -16384]));

      // Every sample has the same magnitude, so rms equals that magnitude.
      expect(meter.rms, closeTo(16384 / 32768, 1e-9));
    });

    test('treats an all-zero buffer as silence', () {
      final meter = PcmLevelMeter()..addBytes(pcm16(List.filled(100, 0)));

      expect(meter.sampleCount, 100);
      expect(meter.rms, 0);
      expect(meter.peak, 0);
    });

    test('carries an odd trailing byte across events', () {
      // The same four samples, but split so that a sample straddles the
      // boundary between the two stream events.
      final whole = pcm16([1000, -2000, 3000, -4000]);
      final firstEvent = Uint8List.sublistView(whole, 0, 3);
      final secondEvent = Uint8List.sublistView(whole, 3);

      final split = PcmLevelMeter()
        ..addBytes(firstEvent)
        ..addBytes(secondEvent);

      final unsplit = PcmLevelMeter()..addBytes(whole);

      expect(split.sampleCount, unsplit.sampleCount);
      expect(split.rms, closeTo(unsplit.rms, 1e-12));
      expect(split.peak, closeTo(unsplit.peak, 1e-12));
    });

    test('survives being fed one byte at a time', () {
      final whole = pcm16([5000, -6000, 7000, -8000, 9000]);

      final drip = PcmLevelMeter();
      for (var i = 0; i < whole.length; i++) {
        drip.addBytes(Uint8List.sublistView(whole, i, i + 1));
      }

      final unsplit = PcmLevelMeter()..addBytes(whole);

      expect(drip.sampleCount, unsplit.sampleCount);
      expect(drip.rms, closeTo(unsplit.rms, 1e-12));
    });

    test('ignores an empty event without losing a held byte', () {
      final whole = pcm16([1234, -4321]);

      final meter = PcmLevelMeter()
        ..addBytes(Uint8List.sublistView(whole, 0, 1))
        ..addBytes(Uint8List(0))
        ..addBytes(Uint8List.sublistView(whole, 1));

      final unsplit = PcmLevelMeter()..addBytes(whole);

      expect(meter.sampleCount, unsplit.sampleCount);
      expect(meter.rms, closeTo(unsplit.rms, 1e-12));
    });

    test('reset clears the measurement window but keeps stream alignment', () {
      final whole = pcm16([1000, -2000, 3000, -4000]);

      final meter = PcmLevelMeter()
        // Leaves one byte held back mid-sample.
        ..addBytes(Uint8List.sublistView(whole, 0, 3))
        ..reset()
        ..addBytes(Uint8List.sublistView(whole, 3));

      // The held byte must still pair with the next event's first byte,
      // otherwise every following sample would be misread.
      expect(meter.sampleCount, 3);
      expect(meter.peak, closeTo(4000 / 32768, 1e-9));
    });
  });
}
