import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/note_folders_table.dart';
import '../tables/preferences_table.dart';
import '../tables/saved_notes_table.dart';

part 'saved_notes_dao.g.dart';

/// A folder plus how many notes are in it, for the library's filter chips.
class FolderSummary {
  const FolderSummary({required this.folder, required this.noteCount});

  final NoteFolder folder;
  final int noteCount;
}

/// The saved-notes library: notes the user kept, and the folders they sort
/// them into.
@DriftAccessor(tables: [NoteFolders, SavedNotes])
class SavedNotesDao extends DatabaseAccessor<AppDatabase>
    with _$SavedNotesDaoMixin {
  SavedNotesDao(super.db);

  static const maxFolderNameLength = 60;
  static const maxTitleLength = 120;

  /// Folders in the order they were made, each with its note count. Creation
  /// order rather than alphabetical: SQLite's NOCASE only folds ASCII, so
  /// „Čeština" would sort after „Z", and a new folder landing at the end —
  /// right next to the chip that created it — is easier to find anyway.
  Stream<List<FolderSummary>> watchFolders() {
    final count = savedNotes.id.count();
    final query = select(noteFolders).join([
      leftOuterJoin(savedNotes, savedNotes.folderId.equalsExp(noteFolders.id)),
    ])
      ..addColumns([count])
      ..groupBy([noteFolders.id])
      ..orderBy([
        OrderingTerm.asc(noteFolders.createdAt),
        OrderingTerm.asc(noteFolders.id),
      ]);

    return query
        .map((row) => FolderSummary(
              folder: row.readTable(noteFolders),
              noteCount: row.read(count) ?? 0,
            ))
        .watch();
  }

  Future<List<NoteFolder>> folders() => (select(noteFolders)
        ..orderBy([
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
        title: _required(title, maxTitleLength, 'title'),
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
        title: Value(_required(title, maxTitleLength, 'title')),
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

  Future<void> deleteNote(int id) =>
      (delete(savedNotes)..where((t) => t.id.equals(id))).go();

  /// Creates a folder, or returns the one that already has this name.
  ///
  /// Compared case-insensitively in Dart rather than with SQL `lower()`, which
  /// only folds ASCII: „čeština" and „Čeština" must be the same folder, not two
  /// chips that look identical.
  Future<int> createFolder(String name) async {
    final clean = _required(name, maxFolderNameLength, 'name');
    final key = clean.toLowerCase();
    for (final folder in await folders()) {
      if (folder.name.toLowerCase() == key) return folder.id;
    }
    return into(noteFolders).insert(
      NoteFoldersCompanion.insert(name: clean, createdAt: DateTime.now()),
    );
  }

  Future<void> renameFolder(int id, String name) =>
      (update(noteFolders)..where((t) => t.id.equals(id))).write(
        NoteFoldersCompanion(
          name: Value(_required(name, maxFolderNameLength, 'name')),
        ),
      );

  /// Deletes the folder and keeps its notes, which move to „Bez složky". A
  /// folder is a label on notes; removing the label must not cost the notes.
  Future<void> deleteFolder(int id) => transaction(() async {
        await (update(savedNotes)..where((t) => t.folderId.equals(id)))
            .write(const SavedNotesCompanion(folderId: Value(null)));
        await (delete(noteFolders)..where((t) => t.id.equals(id))).go();
      });

  /// Trimmed and cut to [max] UTF-16 units — the unit drift's length check
  /// counts in — without splitting a surrogate pair. Blank is an error: the
  /// UI disables its save button for it, so reaching here blank is a bug.
  static String _required(String value, int max, String field) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be blank');
    }
    if (trimmed.length <= max) return trimmed;

    final buffer = StringBuffer();
    var length = 0;
    for (final rune in trimmed.runes) {
      final units = rune > 0xFFFF ? 2 : 1;
      if (length + units > max) break;
      buffer.writeCharCode(rune);
      length += units;
    }
    return buffer.toString().trimRight();
  }
}
