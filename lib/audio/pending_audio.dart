import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/logging.dart';
import '../core/paths.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/transcript_segments_table.dart';
import '../data/db/tables/upload_queue_table.dart';
import 'wav_writer.dart';

/// The audio the chunker has not closed yet, kept on disk so a killed app
/// loses seconds rather than up to half a minute.
///
/// Layout: `AMP1`, uint32 sequence, uint32 startMs (little endian), then raw
/// PCM16. Overwritten every few seconds while recording, deleted once the
/// chunk it belonged to has gone out normally.
const String kPendingAudioName = 'pending.pcm';
const List<int> _magic = [0x41, 0x4D, 0x50, 0x31]; // "AMP1"
const int _headerBytes = 12;

class PendingAudio {
  const PendingAudio({
    required this.sequence,
    required this.startMs,
    required this.pcm,
  });

  final int sequence;
  final int startMs;
  final Uint8List pcm;

  int get durationMs =>
      (pcm.length * 1000) ~/ (kSampleRateHz * kChannels * (kBitsPerSample ~/ 8));
}

String pendingAudioPath(String sessionDir) =>
    p.join(sessionDir, kPendingAudioName);

/// Written to a sibling file and renamed, so a kill in the middle of a write
/// leaves the previous complete snapshot instead of a torn one.
Future<void> writePendingAudio(
  String sessionDir, {
  required int sequence,
  required int startMs,
  required Uint8List bytes,
}) async {
  final target = File(pendingAudioPath(sessionDir));
  await target.parent.create(recursive: true);
  final header = ByteData(_headerBytes);
  for (var i = 0; i < _magic.length; i++) {
    header.setUint8(i, _magic[i]);
  }
  header.setUint32(4, sequence, Endian.little);
  header.setUint32(8, startMs, Endian.little);

  final temp = File('${target.path}.tmp');
  final sink = temp.openWrite();
  try {
    sink.add(header.buffer.asUint8List());
    sink.add(bytes);
    await sink.flush();
  } finally {
    await sink.close();
  }
  await temp.rename(target.path);
}

/// Null when there is no file or it is not one of ours.
Future<PendingAudio?> readPendingAudio(String sessionDir) async {
  final file = File(pendingAudioPath(sessionDir));
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length < _headerBytes) return null;
  for (var i = 0; i < _magic.length; i++) {
    if (bytes[i] != _magic[i]) return null;
  }
  final header = ByteData.sublistView(bytes, 0, _headerBytes);
  // A snapshot cut mid-sample would put half a sample into the WAV.
  final usable = (bytes.length - _headerBytes) & ~1;
  return PendingAudio(
    sequence: header.getUint32(4, Endian.little),
    startMs: header.getUint32(8, Endian.little),
    pcm: Uint8List.sublistView(bytes, _headerBytes, _headerBytes + usable),
  );
}

Future<void> deletePendingAudio(String sessionDir) async {
  for (final path in [
    pendingAudioPath(sessionDir),
    '${pendingAudioPath(sessionDir)}.tmp',
  ]) {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      AppLog.d('audio.pending', 'could not delete $path (${e.osError?.errorCode})');
    }
  }
}

/// How much of [pcm] is louder than [threshold], in whole 100 ms frames — the
/// same yardstick the chunker uses, for audio that never went through it.
int voicedMsOf(
  Uint8List pcm, {
  double threshold = kVoicedRmsThreshold,
  int frameMs = 100,
}) {
  final frameBytes = (kSampleRateHz * kChannels * 2 * frameMs) ~/ 1000;
  var voiced = 0;
  for (var start = 0; start + frameBytes <= pcm.length; start += frameBytes) {
    var sum = 0.0;
    for (var i = start; i < start + frameBytes; i += 2) {
      final u = pcm[i] | (pcm[i + 1] << 8);
      final s = u >= 0x8000 ? u - 0x10000 : u;
      sum += s * s;
    }
    final rms = math.sqrt(sum / (frameBytes ~/ 2)) / 32768.0;
    if (rms >= threshold) voiced += frameMs;
  }
  return voiced;
}

/// Turns every `pending.pcm` a previous run left behind into a normal chunk.
///
/// Runs at startup, before anything can be recording. A snapshot whose
/// sequence is already a segment is stale (the app died between closing the
/// chunk and deleting the file) and is only removed. Returns the ids of the
/// meetings that got a chunk back.
Future<List<int>> recoverPendingAudio({
  required AppDatabase db,
  required String docsPath,
}) async {
  final root = Directory(p.join(docsPath, kRecordingsDirName));
  if (!await root.exists()) return const [];

  final recovered = <int>[];
  await for (final entry in root.list()) {
    if (entry is! Directory) continue;
    final match = RegExp(r'^meeting_(\d+)$').firstMatch(p.basename(entry.path));
    if (match == null) continue;
    final meetingId = int.parse(match.group(1)!);

    try {
      final pending = await readPendingAudio(entry.path);
      if (pending == null) {
        await deletePendingAudio(entry.path);
        continue;
      }
      final next = await db.transcriptSegmentsDao.nextSequenceForMeeting(
        meetingId,
      );
      final meeting = await db.meetingsDao.watchMeetingByIdOnce(meetingId);
      if (meeting == null ||
          pending.sequence < next ||
          pending.durationMs < kMinTranscribableDuration.inMilliseconds) {
        await deletePendingAudio(entry.path);
        continue;
      }

      final name = 'chunk_${pending.sequence.toString().padLeft(4, '0')}.wav';
      final path = p.join(entry.path, name);
      await writeWavFile(
        path: path,
        pcmFrames: [pending.pcm],
        pcmByteLength: pending.pcm.length,
      );
      final stored = toStoredPath(docsPath, path);
      final voiced = voicedMsOf(pending.pcm);
      final skip = voiced < kMinVoicedDuration.inMilliseconds;

      final segmentId = await db.transcriptSegmentsDao.insertSegment(
        TranscriptSegmentsCompanion.insert(
          meetingId: meetingId,
          sequence: pending.sequence,
          startMs: pending.startMs,
          endMs: pending.startMs + pending.durationMs,
          status: skip ? SegmentStatus.transcribed : SegmentStatus.pending,
          localAudioPath: stored,
          createdAt: DateTime.now(),
          voicedMs: Value(voiced),
          cutReason: const Value('recovered'),
        ),
      );
      if (!skip) {
        final now = DateTime.now();
        await db.uploadQueueDao.enqueue(
          UploadQueueCompanion.insert(
            segmentId: segmentId,
            meetingId: meetingId,
            localFilePath: stored,
            status: QueueStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await deletePendingAudio(entry.path);
      recovered.add(meetingId);
      AppLog.d(
        'audio.pending',
        'recovered ${pending.durationMs} ms of meeting $meetingId as chunk '
        '${pending.sequence}',
      );
    } catch (e, st) {
      // One unreadable folder must not stop the others from being recovered.
      AppLog.e('audio.pending', 'recovery of ${p.basename(entry.path)} failed', e, st);
    }
  }
  return recovered;
}
