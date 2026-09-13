import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/upload_queue_table.dart';

part 'upload_queue_dao.g.dart';

@DriftAccessor(tables: [UploadQueue])
class UploadQueueDao extends DatabaseAccessor<AppDatabase> with _$UploadQueueDaoMixin {
  UploadQueueDao(super.db);

  Stream<List<UploadQueueData>> watchQueue() {
    return (select(uploadQueue)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Rows to (re)process now: never-attempted `pending` rows, or
  /// `failedRetryable` rows whose backoff has elapsed. This is what makes
  /// the queue auto-resume after an app restart.
  Future<List<UploadQueueData>> dueRows(DateTime now) {
    return (select(uploadQueue)
          ..where((t) =>
              t.status.equalsValue(QueueStatus.pending) |
              (t.status.equalsValue(QueueStatus.failedRetryable) &
                  t.nextRetryAt.isSmallerOrEqualValue(now)))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Emits the number of rows the worker still has work for. Cheaper to watch
  /// than the whole queue, and it re-fires on every write to the table, which
  /// is exactly the "a chunk was just enqueued" signal the worker needs.
  Stream<int> watchOutstandingCount() {
    final count = uploadQueue.id.count();
    final query = selectOnly(uploadQueue)
      ..addColumns([count])
      ..where(
        uploadQueue.status.equalsValue(QueueStatus.pending) |
            uploadQueue.status.equalsValue(QueueStatus.uploading) |
            uploadQueue.status.equalsValue(QueueStatus.failedRetryable),
      );
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Brings every waiting retry forward to now.
  ///
  /// Called when connectivity is restored: the reason those rows are waiting
  /// has demonstrably gone away, so sitting out the rest of a backoff that can
  /// be minutes long would just delay the transcript for nothing.
  /// [attemptCount] is deliberately left alone, so a chunk that keeps failing
  /// for its own reasons still runs out of attempts.
  Future<int> clearRetryBackoff() =>
      (update(uploadQueue)
            ..where((t) => t.status.equalsValue(QueueStatus.failedRetryable)))
          .write(
        UploadQueueCompanion(
          nextRetryAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Puts a parked row back in play at the user's request.
  ///
  /// [attemptCount] is reset, unlike in [clearRetryBackoff]: a row only reaches
  /// `failedPermanent` after the worker gave up, so "retry" has to mean a fresh
  /// budget or the button would do nothing. Rows that already succeeded are
  /// left alone, so a stray tap cannot re-upload a finished chunk.
  Future<int> requeueForSegment(int segmentId) => (update(uploadQueue)
        ..where((t) =>
            t.segmentId.equals(segmentId) &
            t.status.equalsValue(QueueStatus.succeeded).not()))
      .write(
        UploadQueueCompanion(
          status: const Value(QueueStatus.pending),
          attemptCount: const Value(0),
          nextRetryAt: const Value(null),
          lastError: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// A row left as `uploading` can only mean the app died mid-upload — nothing
  /// is in flight after a cold start. Returning it to `pending` is what stops
  /// such a row from being stranded forever.
  Future<int> resetStuckUploads() =>
      (update(uploadQueue)..where((t) => t.status.equalsValue(QueueStatus.uploading)))
          .write(
        UploadQueueCompanion(
          status: const Value(QueueStatus.pending),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> enqueue(UploadQueueCompanion entry) => into(uploadQueue).insert(entry);

  Future<void> markUploading(int id) => (update(uploadQueue)..where((t) => t.id.equals(id)))
      .write(UploadQueueCompanion(status: Value(QueueStatus.uploading), updatedAt: Value(DateTime.now())));

  Future<void> markSucceeded(int id) => (update(uploadQueue)..where((t) => t.id.equals(id)))
      .write(UploadQueueCompanion(status: Value(QueueStatus.succeeded), updatedAt: Value(DateTime.now())));

  Future<void> markFailedRetryable(int id, int attemptCount, DateTime nextRetryAt, String error) =>
      (update(uploadQueue)..where((t) => t.id.equals(id))).write(
        UploadQueueCompanion(
          status: const Value(QueueStatus.failedRetryable),
          attemptCount: Value(attemptCount),
          nextRetryAt: Value(nextRetryAt),
          lastError: Value(error),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> markFailedPermanent(int id, String error) =>
      (update(uploadQueue)..where((t) => t.id.equals(id))).write(
        UploadQueueCompanion(
          status: const Value(QueueStatus.failedPermanent),
          lastError: Value(error),
          updatedAt: Value(DateTime.now()),
        ),
      );
}
