import 'package:drift/drift.dart';

import 'preferences_table.dart';

/// Notes the user chose to keep, in the library.
///
/// A snapshot rather than a link to `meeting_notes`: regenerating a meeting's
/// notes at another depth, or deleting the meeting altogether, must never
/// change or lose something the user saved. [meetingId] only remembers where
/// the note came from, and is cleared when that meeting is deleted.
class SavedNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get content => text()();

  /// Null means "Bez složky". Deleting a folder moves its notes here rather
  /// than deleting them.
  IntColumn get folderId => integer().nullable()();

  IntColumn get meetingId => integer().nullable()();

  /// The depth the notes were generated at, for the label on the note. Null
  /// once the user has edited the text by hand — it is no longer that output.
  IntColumn get depth => intEnum<NotesDepth>().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
