import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/high_pass.dart';

Uint8List _pcm(List<double> samples) {
  final out = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(out);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(
      i * 2,
      samples[i].round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  return out;
}

Int16List _samples(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  return Int16List.fromList([
    for (var i = 0; i + 1 < bytes.length; i += 2)
      view.getInt16(i, Endian.little),
  ]);
}

List<double> _sine(double hz, double amplitude, {int count = 16000}) => [
  for (var i = 0; i < count; i++)
    amplitude * math.sin(2 * math.pi * hz * i / 16000),
];

/// RMS of the second half, after the filter has settled.
double _rms(Int16List s) {
  var sum = 0.0;
  for (var i = s.length ~/ 2; i < s.length; i++) {
    sum += s[i] * s[i];
  }
  return math.sqrt(sum / (s.length - s.length ~/ 2));
}

double _db(double a, double b) => 20 * math.log(a / b) / math.ln10;

void main() {
  test('removes a DC offset', () {
    final out = _samples(
      HighPassFilter().process(_pcm(List.filled(16000, 3000))),
    );
    expect(_db(_rms(out) + 1e-9, 3000), lessThan(-20));
  });

  test('attenuates rumble below the cutoff', () {
    final out = _samples(HighPassFilter().process(_pcm(_sine(30, 10000))));
    expect(_db(_rms(out), 10000 / math.sqrt2), lessThan(-14));
    // A second-order filter gives ~17 dB at 30 Hz; check it at 20 Hz for 20 dB.
    final low = _samples(HighPassFilter().process(_pcm(_sine(20, 10000))));
    expect(_db(_rms(low), 10000 / math.sqrt2), lessThan(-20));
  });

  test('keeps speech frequencies within 0.5 dB', () {
    final out = _samples(HighPassFilter().process(_pcm(_sine(1000, 10000))));
    expect(_db(_rms(out), 10000 / math.sqrt2).abs(), lessThan(0.5));
  });

  test('returns as many bytes as it was given', () {
    final input = _pcm(_sine(440, 5000, count: 1234));
    expect(HighPassFilter().process(input).length, input.length);
  });

  test('never overflows on a full-scale square wave', () {
    final square = [
      for (var i = 0; i < 16000; i++) (i ~/ 8).isEven ? 32767.0 : -32768.0,
    ];
    final out = _samples(HighPassFilter().process(_pcm(square)));
    expect(out.length, square.length);
  });

  test('split events, even mid-sample, equal one event', () {
    final input = _pcm(_sine(300, 8000, count: 4000));
    final whole = HighPassFilter().process(input);

    final filter = HighPassFilter();
    final parts = BytesBuilder();
    var offset = 0;
    for (final size in [1, 7, 300, 3, 1000, 2]) {
      parts.add(
        filter.process(Uint8List.sublistView(input, offset, offset + size)),
      );
      offset += size;
    }
    parts.add(filter.process(Uint8List.sublistView(input, offset)));
    expect(parts.toBytes(), whole);
  });
}
