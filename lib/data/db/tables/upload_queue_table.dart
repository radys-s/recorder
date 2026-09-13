import 'package:drift/drift.dart';

enum QueueStatus { pending, uploading, succeeded, failedRetryable, failedPermanent }

/// Decoupled local queue for chunk uploads. The worker picks up
/// `pending` or due `failedRetryable` rows on app start (auto-resume) and
/// after every write, independent of the recording/chunking pipeline.
class UploadQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get segmentId => integer()();
  IntColumn get meetingId => integer()();
  TextColumn get localFilePath => text()();
  IntColumn get status => intEnum<QueueStatus>()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
