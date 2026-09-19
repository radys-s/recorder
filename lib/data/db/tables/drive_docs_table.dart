import 'package:drift/drift.dart';

/// Which of a subject's two Google Docs a row describes. Stored by index, so
/// new kinds are appended.
enum DriveDocKind { notes, transcripts }

/// The Google Docs a subject is mirrored into for NotebookLM.
///
/// [contentHash] is the hash of what was last uploaded, so an unchanged
/// subject costs no request. [error] is the last failure for this doc, shown
/// in Settings; it is cleared by the next successful upload.
class DriveDocs extends Table {
  IntColumn get subjectId => integer()();
  IntColumn get kind => intEnum<DriveDocKind>()();
  TextColumn get docId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  TextColumn get contentHash => text().nullable()();
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {subjectId, kind};
}
