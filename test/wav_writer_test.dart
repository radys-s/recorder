import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/wav_writer.dart';
import 'package:recorder/core/constants.dart';

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));

void main() {
  group('buildWavHeader', () {
    test('lays out a canonical 44-byte PCM16 mono 16kHz header', () {
      final header = buildWavHeader(pcmByteLength: 960000);
      final data = ByteData.view(header.buffer);

      expect(header.length, kWavHeaderSize);
      expect(_tag(header, 0), 'RIFF');
      expect(_tag(header, 8), 'WAVE');
      expect(_tag(header, 12), 'fmt ');
      expect(_tag(header, 36), 'data');

      expect(data.getUint32(4, Endian.little), 36 + 960000);
      expect(data.getUint32(16, Endian.little), 16, reason: 'PCM fmt chunk size');
      expect(data.getUint16(20, Endian.little), 1, reason: 'format 1 = uncompressed');
      expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(data.getUint32(24, Endian.little), 16000);
      expect(data.getUint32(28, Endian.little), 32000, reason: 'byte rate');
      expect(data.getUint16(32, Endian.little), 2, reason: 'block align');
      expect(data.getUint16(34, Endian.little), 16);
      expect(data.getUint32(40, Endian.little), 960000);
    });

    test('reports an empty payload without corrupting the sizes', () {
      final data = ByteData.view(buildWavHeader(pcmByteLength: 0).buffer);
      expect(data.getUint32(4, Endian.little), 36);
      expect(data.getUint32(40, Endian.little), 0);
    });
  });

  group('writeWavFile', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('wav_writer_test');
    });

    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('writes header + payload and preserves frame order', () async {
      final frames = [
        Uint8List.fromList([1, 2, 3, 4]),
        Uint8List.fromList([5, 6]),
        Uint8List.fromList([7, 8, 9, 10]),
      ];
      final path = '${dir.path}/chunk.wav';

      final file = await writeWavFile(
        path: path,
        pcmFrames: frames,
        pcmByteLength: 10,
      );

      final bytes = await file.readAsBytes();
      expect(bytes.length, kWavHeaderSize + 10);
      expect(_tag(bytes, 0), 'RIFF');
      expect(
        bytes.sublist(kWavHeaderSize),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );
      expect(ByteData.view(bytes.buffer).getUint32(40, Endian.little), 10);
    });

    test('creates missing parent directories', () async {
      final path = '${dir.path}/meeting-7/chunks/000.wav';
      await writeWavFile(
        path: path,
        pcmFrames: [Uint8List.fromList([0, 0])],
        pcmByteLength: 2,
      );
      expect(File(path).existsSync(), isTrue);
    });
  });
}
