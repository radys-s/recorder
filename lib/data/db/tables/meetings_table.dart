import 'package:drift/drift.dart';

/// A meeting/interview recording. `endedAt == null` while recording is in
/// progress; it also flags an "orphaned" recording (app killed mid-meeting)
/// on next launch.
class Meetings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// Set when startup had to close this meeting because the app died while it
  /// was recording. Persisted rather than derived: once `endedAt` is filled in
  /// the evidence is gone, and the list would quietly start claiming the
  /// recording ended normally.
  BoolColumn get interrupted => boolean().withDefault(const Constant(false))();

  /// The subject this lesson belongs to; null for an ordinary meeting, which
  /// keeps the meeting prompts and notes.
  IntColumn get subjectId => integer().nullable()();

  /// Rules for this lesson only, set at the start sheet. Rules typed into the
  /// chat later are chat messages and come after these.
  TextColumn get rules => text().nullable()();
}
