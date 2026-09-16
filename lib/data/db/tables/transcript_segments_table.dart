import 'package:drift/drift.dart';

enum SegmentStatus { pending, uploading, transcribed, failed }

/// One audio chunk of a meeting and its transcription state. Rows are
/// inserted at chunk-finalize time regardless of network state, so
/// "transcript so far, mid-recording" already works by construction.
class TranscriptSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get meetingId => integer()();
  IntColumn get sequence => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get content => text().nullable()();
  IntColumn get status => intEnum<SegmentStatus>()();
  TextColumn get localAudioPath => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// How much of the chunk sounded like speech when it was recorded. Lets the
  /// worker reject a transcript far longer than the speech it came from;
  /// null for rows written before v12, which skip that check.
  IntColumn get voicedMs => integer().nullable()();
}
