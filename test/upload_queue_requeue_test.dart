import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/upload_queue_table.dart';

/// „Zkusit znovu" may only move parked rows: a finished chunk must not be
/// uploaded again, and one being uploaded must not be reset under the worker.
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('only a parked row goes back in line', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = db.uploadQueueDao;
    final at = DateTime(2026, 11, 18, 8);
    Future<int> row(int segment, QueueStatus status) => dao.enqueue(
      UploadQueueCompanion.insert(
        segmentId: segment,
        meetingId: 1,
        localFilePath: 'chunk_$segment.wav',
        status: status,
        createdAt: at,
        updatedAt: at,
      ),
    );
    await row(1, QueueStatus.failedPermanent);
    await row(2, QueueStatus.succeeded);
    await row(3, QueueStatus.uploading);

    expect(await dao.requeueForSegment(1), 1);
    expect(await dao.requeueForSegment(2), 0);
    expect(await dao.requeueForSegment(3), 0);

    final rows = await db.select(db.uploadQueue).get();
    final bySegment = {for (final r in rows) r.segmentId: r.status};
    expect(bySegment, {
      1: QueueStatus.pending,
      2: QueueStatus.succeeded,
      3: QueueStatus.uploading,
    });
  });
}
