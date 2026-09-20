import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/pcm_chunker.dart';

/// 16000 Hz * 1 channel * 2 bytes.
const _bytesPerMs = 32;

/// Builds [ms] of PCM16 alternating between +[amplitude] and -[amplitude],
/// so the frame's RMS is exactly [amplitude]. Amplitude 0 is silence; the
/// chunker's threshold is 0.01 * 32768 ≈ 328.
Uint8List _pcm({required int ms, required int amplitude}) {
  final bytes = Uint8List(ms * _bytesPerMs);
  for (var i = 0; i < bytes.length ~/ 2; i++) {
    final sample = i.isEven ? amplitude : -amplitude;
    final unsigned = sample < 0 ? sample + 0x10000 : sample;
    bytes[i * 2] = unsigned & 0xFF;
    bytes[i * 2 + 1] = (unsigned >> 8) & 0xFF;
  }
  return bytes;
}

Uint8List _loud(int ms) => _pcm(ms: ms, amplitude: 6000);
Uint8List _silent(int ms) => _pcm(ms: ms, amplitude: 0);

/// Feeds [bytes] in events of [eventSize], mimicking the platform stream's
/// arbitrary (and not necessarily 2-byte aligned) event sizes.
void _feed(PcmChunker chunker, Uint8List bytes, {int eventSize = 4096}) {
  for (var offset = 0; offset < bytes.length; offset += eventSize) {
    final end = (offset + eventSize).clamp(0, bytes.length);
    chunker.addBytes(Uint8List.sublistView(bytes, offset, end));
  }
}

void main() {
  late List<PcmChunk> chunks;
  late PcmChunker chunker;

  setUp(() {
    chunks = [];
    chunker = PcmChunker(onChunk: chunks.add);
  });

  test('emits nothing before the minimum duration', () {
    _feed(chunker, _loud(5000));
    _feed(chunker, _silent(5000));
    expect(chunks, isEmpty);
  });

  test('cuts at the hard cap when the signal never goes quiet', () {
    _feed(chunker, _loud(30000));

    expect(chunks, hasLength(1));
    expect(chunks.single.startMs, 0);
    expect(chunks.single.endMs, 30000);
    expect(chunks.single.byteLength, 30000 * _bytesPerMs);
    expect(chunks.single.cutReason, ChunkCutReason.hardCap);
  });

  test('cuts on sustained silence between the minimum and the target', () {
    _feed(chunker, _loud(16000));
    _feed(chunker, _silent(600));

    expect(chunks, hasLength(1));
    expect(chunks.single.endMs, 16600);
    expect(chunks.single.cutReason, ChunkCutReason.silence);
  });

  test('ignores a short gap between words before the target', () {
    _feed(chunker, _loud(16000));
    _feed(chunker, _silent(300));
    _feed(chunker, _loud(300));
    expect(chunks, isEmpty, reason: '300ms is below the confident-silence bar');

    // Still cut by the hard cap.
    _feed(chunker, _loud(13400));
    expect(chunks, hasLength(1));
    expect(chunks.single.endMs, 30000);
  });

  test('a single silent frame is enough past the target', () {
    _feed(chunker, _loud(25000));
    expect(chunks, isEmpty);

    _feed(chunker, _silent(100));
    expect(chunks, hasLength(1));
    expect(chunks.single.endMs, 25100);
  });

  test('sequence numbers and the timeline stay gapless across cuts', () {
    _feed(chunker, _loud(65000));
    chunker.flush();

    expect(chunks.map((c) => c.sequence), [0, 1, 2]);
    expect(chunks.map((c) => c.startMs), [0, 30000, 60000]);
    expect(chunks.map((c) => c.endMs), [30000, 60000, 65000]);
    expect(
      chunks.fold<int>(0, (sum, c) => sum + c.byteLength),
      65000 * _bytesPerMs,
    );
  });

  test('flush emits the buffered tail as a short final chunk', () {
    _feed(chunker, _loud(3000));
    expect(chunks, isEmpty);

    chunker.flush();
    expect(chunks, hasLength(1));
    expect(chunks.single.duration, const Duration(seconds: 3));
    expect(chunks.single.cutReason, ChunkCutReason.flush);
  });

  test('flush on an empty chunker emits nothing', () {
    chunker.flush();
    expect(chunks, isEmpty);
  });

  test('manual cut retains its cause for downstream diagnostics', () {
    _feed(chunker, _loud(7000));
    expect(chunker.cut(), isTrue);
    expect(chunks.single.cutReason, ChunkCutReason.manual);
  });

  test('odd-sized stream events produce identical cuts', () {
    final reference = <PcmChunk>[];
    final aligned = PcmChunker(onChunk: reference.add);
    _feed(aligned, _loud(65000), eventSize: 3200);
    aligned.flush();

    _feed(chunker, _loud(65000), eventSize: 777);
    chunker.flush();

    expect(chunks.map((c) => c.endMs), reference.map((c) => c.endMs));
    expect(chunks.map((c) => c.byteLength), reference.map((c) => c.byteLength));
  });

  test('a chunk\'s frames add up to its reported byte length', () {
    _feed(chunker, _loud(30000));
    final chunk = chunks.single;
    expect(
      chunk.frames.fold<int>(0, (sum, f) => sum + f.length),
      chunk.byteLength,
    );
  });

  test('reset clears the buffer and the sequence counter', () {
    _feed(chunker, _loud(10000));
    chunker.reset();
    expect(chunker.bufferedBytes, 0);
    expect(chunker.nextSequence, 0);

    _feed(chunker, _loud(30000));
    expect(chunks.single.sequence, 0);
    expect(chunks.single.startMs, 0);
  });
}
