import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/pcm_chunker.dart';
import 'package:recorder/core/constants.dart';

/// Alternating ±[amplitude] PCM16, so the RMS is exactly amplitude / 32768.
Uint8List _pcm(int ms, int amplitude) {
  final samples = kSampleRateHz * ms ~/ 1000;
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, i.isEven ? amplitude : -amplitude, Endian.little);
  }
  return data.buffer.asUint8List();
}

const _speech = 6000; // ~-15 dBFS
const _between = 1000; // ~-30 dBFS: a breath in a noisy room, never "silence"

void main() {
  late List<PcmChunk> chunks;
  late PcmChunker chunker;

  setUp(() {
    chunks = [];
    chunker = PcmChunker(onChunk: chunks.add);
  });

  void expectGapless(int totalMs) {
    for (var i = 1; i < chunks.length; i++) {
      expect(chunks[i].startMs, chunks[i - 1].endMs, reason: 'chunk $i');
    }
    expect(chunks.first.startMs, 0);
    expect(chunks.last.endMs, totalMs);
  }

  test('continuous speech is cut at a sentence-length dip, not at the cap', () {
    chunker
      ..addBytes(_pcm(17000, _speech))
      ..addBytes(_pcm(500, _between))
      ..addBytes(_pcm(5000, _speech))
      ..flush();
    expect(chunks.first.endMs, 17400);
    expectGapless(22500);
  });

  test('a dip as short as the gap between words is ignored before target', () {
    chunker
      ..addBytes(_pcm(17000, _speech))
      ..addBytes(_pcm(200, _between))
      ..addBytes(_pcm(6800, _speech))
      ..flush();
    expect(chunks, hasLength(1));
  });

  test('past the target a short dip is enough', () {
    chunker
      ..addBytes(_pcm(26000, _speech))
      ..addBytes(_pcm(200, _between))
      ..addBytes(_pcm(1000, _speech))
      ..flush();
    expect(chunks.first.endMs, 26200);
  });

  test('at the hard cap the chunk ends at the quietest recent point', () {
    chunker
      ..addBytes(_pcm(28000, _speech))
      ..addBytes(_pcm(100, _between))
      ..addBytes(_pcm(11900, _speech))
      ..flush();
    expect(chunks.first.endMs, 28100);
    // The audio after the cut starts the next chunk rather than being lost.
    expect(chunks[1].startMs, 28100);
    expectGapless(40000);
    final bytes = chunks.fold<int>(0, (s, c) => s + c.byteLength);
    expect(bytes, 40000 * kSampleRateHz * 2 ~/ 1000);
  });

  test('voiced time is split with the audio at a quietest-point cut', () {
    chunker
      ..addBytes(_pcm(28000, _speech))
      ..addBytes(_pcm(100, _between))
      ..addBytes(_pcm(1900, _speech))
      ..flush();
    expect(chunks.map((c) => c.voicedMs), [28100, 1900]);
  });

  test('cut() emits whole frames and the next chunk starts where it ended',
      () {
    chunker.addBytes(_pcm(2050, _speech));
    expect(chunker.cut(), isTrue);
    expect(chunks.single.endMs, 2000);
    chunker
      ..addBytes(_pcm(1000, _speech))
      ..flush();
    expect(chunks[1].startMs, 2000);
    expect(chunks[1].endMs, 3050);
    expect(chunker.cut(), isFalse);
  });

  test('every frame level is reported for calibration', () {
    final levels = <double>[];
    PcmChunker(onChunk: (_) {}, onFrameLevel: levels.add)
        .addBytes(_pcm(1000, 3277));
    expect(levels, hasLength(10));
    expect(levels.first, closeTo(0.1, 1e-3));
  });
}
