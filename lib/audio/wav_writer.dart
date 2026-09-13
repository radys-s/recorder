import 'dart:io';
import 'dart:typed_data';

import '../core/constants.dart';

/// Builds the canonical 44-byte RIFF/WAVE header for uncompressed PCM.
///
/// [pcmByteLength] is the payload size *without* the header. Every multi-byte
/// field is little-endian, which is what the WAV spec mandates regardless of
/// host endianness.
Uint8List buildWavHeader({
  required int pcmByteLength,
  int sampleRate = kSampleRateHz,
  int channels = kChannels,
  int bitsPerSample = kBitsPerSample,
}) {
  final bytesPerSample = bitsPerSample ~/ 8;
  final blockAlign = channels * bytesPerSample;
  final byteRate = sampleRate * blockAlign;

  final bytes = Uint8List(kWavHeaderSize);
  final data = ByteData.view(bytes.buffer);

  void tag(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  tag(0, 'RIFF');
  // Size of everything after this field: the 36 remaining header bytes + payload.
  data.setUint32(4, 36 + pcmByteLength, Endian.little);
  tag(8, 'WAVE');

  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little); // fmt chunk size for PCM
  data.setUint16(20, 1, Endian.little); // format 1 = uncompressed PCM
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);

  tag(36, 'data');
  data.setUint32(40, pcmByteLength, Endian.little);

  return bytes;
}

/// Writes [pcmFrames] to [path] as a WAV file.
///
/// The payload is streamed frame by frame rather than concatenated first, so
/// writing a 30s chunk never needs a second ~1MB allocation. [pcmByteLength]
/// must be the exact total of [pcmFrames] — it goes into the header, and a
/// wrong value produces a file that players either truncate or reject.
Future<File> writeWavFile({
  required String path,
  required Iterable<List<int>> pcmFrames,
  required int pcmByteLength,
  int sampleRate = kSampleRateHz,
  int channels = kChannels,
  int bitsPerSample = kBitsPerSample,
}) async {
  final file = File(path);
  await file.parent.create(recursive: true);

  final sink = file.openWrite();
  try {
    sink.add(
      buildWavHeader(
        pcmByteLength: pcmByteLength,
        sampleRate: sampleRate,
        channels: channels,
        bitsPerSample: bitsPerSample,
      ),
    );
    for (final frame in pcmFrames) {
      sink.add(frame);
    }
    await sink.flush();
  } finally {
    await sink.close();
  }

  return file;
}
