import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/preferences_table.dart';
import '../tables/saved_notes_table.dart';
import '../tables/subjects_table.dart';
import 'subjects_dao.dart';

part 'saved_notes_dao.g.dart';

/// A subject plus how many notes are filed under it, for the library's filter
/// chips.
class FolderSummary {
  const FolderSummary({required this.folder, required this.noteCount});

  final Subject folder;
  final int noteCount;
}

/// The saved-notes library: notes the user kept, and the subjects they file
/// them under. Subjects were note folders before schema v10, which is why the
/// method names still say folder.
@DriftAccessor(tables: [Subjects, SavedNotes])
class SavedNotesDao extends DatabaseAccessor<AppDatabase>
    with _$SavedNotesDaoMixin {
  SavedNotesDao(super.db);

  static const maxFolderNameLength = 60;
  static const maxTitleLength = 120;

  /// Subjects in the order they were made, each with its note count. Creation
  /// order rather than alphabetical: SQLite's NOCASE only folds ASCII, so
  /// „Čeština" would sort after „Z", and a new subject landing at the end —
  /// right next to the chip that created it — is easier to find anyway.
  Stream<List<FolderSummary>> watchFolders() {
    final count = savedNotes.id.count();
    final query = select(subjects).join([
      leftOuterJoin(savedNotes, savedNotes.folderId.equalsExp(subjects.id)),
    ])
      ..addColumns([count])
      ..groupBy([subjects.id])
      ..orderBy([
        OrderingTerm.asc(subjects.sortOrder),
        OrderingTerm.asc(subjects.createdAt),
        OrderingTerm.asc(subjects.id),
      ]);

    return query
        .map((row) => FolderSummary(
              folder: row.readTable(subjects),
              noteCount: row.read(count) ?? 0,
            ))
        .watch();
  }

  Future<List<Subject>> folders() => (select(subjects)
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .get();

  /// Every saved note, most recently edited first.
  Stream<List<SavedNote>> watchNotes() => (select(savedNotes)
        ..orderBy([
          (t) => OrderingTerm.desc(t.updatedAt),
          (t) => OrderingTerm.desc(t.id),
        ]))
      .watch();

  Stream<SavedNote?> watchNote(int id) =>
      (select(savedNotes)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Notes saved from one meeting — how the notes tab knows whether what it is
  /// showing is already in the library.
  Stream<List<SavedNote>> watchForMeeting(int meetingId) =>
      (select(savedNotes)..where((t) => t.meetingId.equals(meetingId))).watch();

  Future<int> saveNote({
    required String title,
    required String content,
    int? folderId,
    int? meetingId,
    NotesDepth? depth,
  }) {
    final now = DateTime.now();
    return into(savedNotes).insert(
      SavedNotesCompanion.insert(
        title: requiredText(title, maxTitleLength, 'title'),
        content: content.trim(),
        folderId: Value(folderId),
        meetingId: Value(meetingId),
        depth: Value(depth),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Rewrites a note by hand. The depth label is dropped once the text itself
  /// changes, because the note is then no longer what that depth produced.
  Future<void> updateNote(
    int id, {
    required String title,
    required String content,
  }) async {
    final current = await (select(savedNotes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (current == null) return;

    final trimmed = content.trim();
    await (update(savedNotes)..where((t) => t.id.equals(id))).write(
      SavedNotesCompanion(
        title: Value(requiredText(title, maxTitleLength, 'title')),
        content: Value(trimmed),
        depth: trimmed == current.content
            ? const Value.absent()
            : const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Moving is filing, not editing, so it leaves `updatedAt` — and with it the
  /// note's place in the list — alone.
  Future<void> moveNote(int id, int? folderId) =>
      (update(savedNotes)..where((t) => t.id.equals(id)))
          .write(SavedNotesCompanion(folderId: Value(folderId)));

  Future<void> deleteNote(int id) => transaction(() async {
    final study = attachedDatabase.studyCards;
    await (update(study)..where((t) => t.noteId.equals(id)))
        .write(const StudyCardsCompanion(noteId: Value(null)));
    await (delete(savedNotes)..where((t) => t.id.equals(id))).go();
  });

  /// Creates a subject, or returns the one that already has this name.
  ///
  /// Compared case-insensitively in Dart rather than with SQL `lower()`, which
  /// only folds ASCII: „čeština" and „Čeština" must be the same subject, not
  /// two chips that look identical.
  Future<int> createFolder(String name) async {
    final clean = requiredText(name, maxFolderNameLength, 'name');
    final key = clean.toLowerCase();
    final existing = await folders();
    for (final folder in existing) {
      if (folder.name.toLowerCase() == key) return folder.id;
    }
    return into(subjects).insert(
      SubjectsCompanion.insert(
        name: clean,
        createdAt: DateTime.now(),
        // Spread new subjects over the palette instead of all starting blue.
        colorIndex: Value(existing.length % SubjectsDao.paletteSize),
      ),
    );
  }

  Future<void> renameFolder(int id, String name) =>
      (update(subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(
          name: Value(requiredText(name, maxFolderNameLength, 'name')),
        ),
      );

  /// Deletes the subject and keeps its notes, which move to „Bez předmětu". A
  /// subject is a label on notes; removing the label must not cost the notes.
  /// Its cards go with it — see [SubjectsDao.deleteSubject].
  Future<void> deleteFolder(int id) => db.subjectsDao.deleteSubject(id);
}
