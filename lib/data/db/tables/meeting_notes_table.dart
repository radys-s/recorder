import 'package:drift/drift.dart';

import 'preferences_table.dart';

enum NotesStatus { generating, ready, failed }

/// AI notes for one meeting.
///
/// At most one row per meeting: regenerating at a different depth replaces the
/// existing row rather than piling up versions, which matches how the screen
/// presents it — one set of notes, remade on demand.
///
/// The row is written as [NotesStatus.generating] *before* the call goes out,
/// so an app kill mid-generation is visible on relaunch instead of silently
/// leaving no trace.
class MeetingNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get meetingId => integer()();
  IntColumn get depth => intEnum<NotesDepth>()();

  /// Null until the first generation succeeds. Kept across a regenerate, so a
  /// failed one leaves the previous notes readable rather than wiping them.
  TextColumn get content => text().nullable()();

  /// Which model produced [content] — worth recording, because the notes will
  /// outlive the model id that made them.
  TextColumn get model => text()();

  IntColumn get status => intEnum<NotesStatus>()();

  /// Up to three topics from a lesson's notes worth keeping as cards, as JSON
  /// (`encodeCardSuggestions`). Cleared whenever new notes land; entries are
  /// removed as the student adds or dismisses them.
  TextColumn get cardSuggestions => text().nullable()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {meetingId},
      ];
}
