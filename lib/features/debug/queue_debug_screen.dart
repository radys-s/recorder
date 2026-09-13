import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../audio/recording_controller.dart';
import '../../core/logging.dart';
import '../../core/paths.dart';
import '../../core/providers.dart';
import '../../data/db/app_database.dart';
import '../../data/db/tables/transcript_segments_table.dart';
import '../../data/db/tables/upload_queue_table.dart';
import '../meeting_detail/meeting_detail_screen.dart';

/// Raw view of the upload queue and the newest transcript, plus buttons that
/// seed known-good and deliberately-broken rows.
///
/// Kept past M9 rather than deleted: it is the fastest way to watch the queue
/// state machine during the dropout and long-run passes, and it is only
/// reachable from the debug-only diagnostics section of Settings.

// ---------------------------------------------------------------------------
// Debug-only providers and widgets, reachable from Settings.
// ---------------------------------------------------------------------------

final _queueRowsProvider = StreamProvider<List<UploadQueueData>>((ref) {
  return ref.watch(appDatabaseProvider).uploadQueueDao.watchQueue();
});

final _meetingsProvider = StreamProvider<List<Meeting>>((ref) {
  return ref.watch(appDatabaseProvider).meetingsDao.watchAllMeetings();
});

final _segmentsProvider =
    StreamProvider.family<List<TranscriptSegment>, int>((ref, meetingId) {
  return ref
      .watch(appDatabaseProvider)
      .transcriptSegmentsDao
      .watchSegmentsForMeeting(meetingId);
});

class QueueDebugScreen extends ConsumerStatefulWidget {
  const QueueDebugScreen({super.key});

  @override
  ConsumerState<QueueDebugScreen> createState() => QueueDebugScreenState();
}

class QueueDebugScreenState extends ConsumerState<QueueDebugScreen> {
  static const _tag = 'queue.debug';

  Timer? _tick;
  String? _localError;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    // Only to keep the elapsed counter moving; recording state itself is
    // pushed by the controller.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// TEMPORARY (M7): pushes the known-good `test_speech.wav` through the real
  /// queue path, so the state machine can be verified against a chunk whose
  /// transcript is known in advance — the emulator's virtual mic only ever
  /// produces silence.
  Future<void> _seedTestChunk() async {
    setState(() {
      _seeding = true;
      _localError = null;
    });

    try {
      final docs = await getApplicationDocumentsDirectory();
      final source = File(p.join(docs.path, 'test_speech.wav'));
      if (!source.existsSync()) {
        setState(() => _localError = 'test_speech.wav not found in app documents.');
        return;
      }

      final db = ref.read(appDatabaseProvider);
      final now = DateTime.now();

      final meetingId = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Seeded test ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
          createdAt: now,
          endedAt: Value(now),
        ),
      );

      final dir = Directory(
        p.join(docs.path, kRecordingsDirName, 'meeting_$meetingId'),
      );
      await dir.create(recursive: true);
      final copy = await source.copy(p.join(dir.path, 'chunk_0000.wav'));
      // Seeded rows have to look exactly like recorded ones, or this
      // screen stops being a way to reproduce what the recorder does.
      final storedPath = toStoredPath(docs.path, copy.path);

      final segmentId = await db.transcriptSegmentsDao.insertSegment(
        TranscriptSegmentsCompanion.insert(
          meetingId: meetingId,
          sequence: 0,
          startMs: 0,
          endMs: 14265,
          status: SegmentStatus.pending,
          localAudioPath: storedPath,
          createdAt: now,
        ),
      );

      await db.uploadQueueDao.enqueue(
        UploadQueueCompanion.insert(
          segmentId: segmentId,
          meetingId: meetingId,
          localFilePath: storedPath,
          status: QueueStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );

      AppLog.d(_tag, 'seeded meeting $meetingId / segment $segmentId from test_speech.wav');
      unawaited(ref.read(queueWorkerProvider).poke());
    } catch (e, st) {
      AppLog.e(_tag, 'failed to seed test chunk', e, st);
      if (mounted) setState(() => _localError = '$e');
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  /// TEMPORARY (M7): enqueues a row pointing at a file that does not exist, to
  /// prove a permanent failure parks instead of retrying forever.
  Future<void> _seedBrokenChunk() async {
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();

    final meetingId = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title: 'Broken row test',
        createdAt: now,
        endedAt: Value(now),
      ),
    );
    // Deliberately absolute as well as absent: a stored path from before
    // paths went relative is used as-is, so this row exercises that path
    // through [resolveStoredPath] on its way to failing.
    const missing = '/data/data/does/not/exist.wav';
    final segmentId = await db.transcriptSegmentsDao.insertSegment(
      TranscriptSegmentsCompanion.insert(
        meetingId: meetingId,
        sequence: 0,
        startMs: 0,
        endMs: 1000,
        status: SegmentStatus.pending,
        localAudioPath: missing,
        createdAt: now,
      ),
    );
    await db.uploadQueueDao.enqueue(
      UploadQueueCompanion.insert(
        segmentId: segmentId,
        meetingId: meetingId,
        localFilePath: missing,
        status: QueueStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    );
    AppLog.d(_tag, 'seeded deliberately broken row for segment $segmentId');
    unawaited(ref.read(queueWorkerProvider).poke());
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(recordingControllerProvider);
    final controller = ref.read(recordingControllerProvider.notifier);
    final error = _localError ?? recording.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue debug (M7)'),
        actions: [
          // TEMPORARY (M8b): a fixed-position way into the detail screen. The
          // tappable meeting title below moves every time a queue row lands,
          // which makes it useless for scripted verification.
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: 'Newest meeting',
            onPressed: () async {
              final list = await ref
                  .read(appDatabaseProvider)
                  .meetingsDao
                  .watchAllMeetings()
                  .first;
              if (list.isEmpty || !context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MeetingDetailScreen(meetingId: list.first.id),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
            ),
          _StatRow(label: 'Recording', value: recording.isRecording ? 'yes' : 'no'),
          _StatRow(label: 'Meeting', value: '${recording.meetingId ?? '—'}'),
          _StatRow(label: 'Elapsed', value: '${recording.elapsed.inSeconds}s'),
          _StatRow(label: 'Chunks', value: '${recording.chunkCount}'),
          _StatRow(label: 'Bytes', value: '${recording.totalBytes}'),
          const SizedBox(height: 8),
          ValueListenableBuilder<({double rms, double peak})>(
            valueListenable: controller.level,
            builder: (_, levels, _) => LinearProgressIndicator(
              value: levels.rms.clamp(0.0, 1.0),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => controller.toggle(),
            icon: Icon(recording.isRecording ? Icons.stop : Icons.mic),
            label: Text(recording.isRecording ? 'Stop recording' : 'Start recording'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _seeding ? null : _seedTestChunk,
                  child: const Text('Seed test chunk'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _seedBrokenChunk,
                  child: const Text('Seed broken row'),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Upload queue', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _QueueList(),
          const Divider(height: 32),
          Text('Transcripts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _TranscriptList(),
        ],
      ),
    );
  }
}

class _QueueList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(_queueRowsProvider);

    return rows.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('queue error: $e'),
      data: (list) {
        if (list.isEmpty) return const Text('empty');
        return Column(
          children: [
            for (final row in list)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: _statusDot(context, row.status),
                title: Text(
                  '#${row.id} seg ${row.segmentId} · ${row.status.name}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'attempts ${row.attemptCount}'
                  '${row.nextRetryAt == null ? '' : ' · retry at ${_time(row.nextRetryAt!)}'}'
                  '${row.lastError == null ? '' : '\n${row.lastError}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                isThreeLine: row.lastError != null,
              ),
          ],
        );
      },
    );
  }

  static String _time(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}';

  static Widget _statusDot(BuildContext context, QueueStatus status) {
    final color = switch (status) {
      QueueStatus.pending => Colors.orange,
      QueueStatus.uploading => Colors.blue,
      QueueStatus.succeeded => Colors.green,
      QueueStatus.failedRetryable => Colors.deepOrange,
      QueueStatus.failedPermanent => Colors.red,
    };
    return Icon(Icons.circle, size: 12, color: color);
  }
}

class _TranscriptList extends ConsumerWidget {
  const _TranscriptList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetings = ref.watch(_meetingsProvider);

    return meetings.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('meetings error: $e'),
      data: (list) {
        if (list.isEmpty) return const Text('no meetings yet');
        // Newest meeting only — enough to watch a transcript fill in.
        final meeting = list.first;
        final segments = ref.watch(_segmentsProvider(meeting.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TEMPORARY (M8b): the only way into the detail screen until the
            // meetings list becomes `home` at M9.
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MeetingDetailScreen(meetingId: meeting.id),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(meeting.title,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 4),
            segments.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('segments error: $e'),
              data: (segs) => segs.isEmpty
                  ? const Text('no segments yet')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in segs)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '[${s.sequence}] ${s.status.name}  ',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  TextSpan(text: s.content ?? '…'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}
