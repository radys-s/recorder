import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/constants.dart';
import 'pcm_gain.dart';
import 'wav_writer.dart';

/// The PCM payload of a WAV file and the format it is in.
class WavPcm {
  const WavPcm({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.pcm,
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final Uint8List pcm;
}

class WavFormatException implements Exception {
  const WavFormatException(this.message);
  final String message;
  @override
  String toString() => 'WavFormatException: $message';
}

/// Reads a RIFF/WAVE file by walking its chunks.
///
/// The app's own chunks have the canonical 44-byte header, but a header is
/// not guaranteed to be 44 bytes — SAPI once wrote an 18-byte `fmt ` chunk
/// and the data began at 46 — so nothing here assumes an offset. A `data`
/// size running past the end of the file (a write cut short) is clamped.
WavPcm parseWav(Uint8List bytes) {
  String tag(int at) => String.fromCharCodes(bytes, at, at + 4);
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const WavFormatException('not a RIFF/WAVE file');
  }
  final view = ByteData.sublistView(bytes);

  int? rate;
  int? channels;
  int? bits;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = tag(at);
    final size = view.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      if (size < 16 || body + 16 > bytes.length) {
        throw const WavFormatException('fmt chunk too short');
      }
      final format = view.getUint16(body, Endian.little);
      if (format != 1) {
        throw WavFormatException('unsupported format $format');
      }
      channels = view.getUint16(body + 2, Endian.little);
      rate = view.getUint32(body + 4, Endian.little);
      bits = view.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (rate == null) throw const WavFormatException('data before fmt');
      final end = math.min(bytes.length, body + size);
      return WavPcm(
        sampleRate: rate,
        channels: channels!,
        bitsPerSample: bits!,
        pcm: Uint8List.sublistView(bytes, body, end),
      );
    }
    // Chunks are padded to an even size.
    at = body + size + (size.isOdd ? 1 : 0);
  }
  throw const WavFormatException('no data chunk');
}

/// Splits PCM16 into 100 ms frames and marks the ones loud enough to be
/// speech, the shape [speechGain] measures.
({List<Uint8List> frames, List<bool> voiced}) framesOf(
  Uint8List pcm, {
  int sampleRate = kSampleRateHz,
  double voicedRms = kRefinedVoicedRms,
}) {
  final frameBytes =
      sampleRate * 2 * kSilenceFrameDuration.inMilliseconds ~/ 1000;
  final frames = <Uint8List>[];
  final voiced = <bool>[];
  for (var at = 0; at < pcm.length; at += frameBytes) {
    final frame =
        Uint8List.sublistView(pcm, at, math.min(pcm.length, at + frameBytes));
    frames.add(frame);
    voiced.add(frameRms(frame) >= voicedRms);
  }
  return (frames: frames, voiced: voiced);
}

/// Joins chunk WAVs into one window WAV at [outputPath], raising each chunk
/// to speech level on its own — the live pass left skipped chunks at their
/// recorded level, and a quiet teacher in one chunk should not be judged by
/// a loud student in the next.
///
/// Missing or unreadable chunks are skipped; the returned count says how
/// many made it. Every chunk must be 16 kHz mono PCM16, which is all the app
/// ever writes.
Future<({int chunks, int pcmBytes})> concatWavFiles({
  required List<String> inputs,
  required String outputPath,
  double maxGain = kAutoMaxGain,
}) async {
  final parts = <Uint8List>[];
  var total = 0;
  var readable = 0;
  for (final path in inputs) {
    final WavPcm wav;
    try {
      wav = parseWav(await File(path).readAsBytes());
    } on FileSystemException {
      continue;
    } on WavFormatException {
      continue;
    }
    if (wav.sampleRate != kSampleRateHz ||
        wav.channels != 1 ||
        wav.bitsPerSample != 16) {
      continue;
    }
    // An odd trailing byte would shift every later sample of the window.
    final even = wav.pcm.length.isOdd
        ? Uint8List.sublistView(wav.pcm, 0, wav.pcm.length - 1)
        : wav.pcm;
    readable++;
    final split = framesOf(even);
    final gain = speechGain(split.frames, split.voiced, maxGain: maxGain);
    for (final frame in applyGain(split.frames, gain)) {
      parts.add(frame);
      total += frame.length;
    }
  }

  if (total > 0) {
    await writeWavFile(
      path: outputPath,
      pcmFrames: parts,
      pcmByteLength: total,
    );
  }
  return (chunks: readable, pcmBytes: total);
}
