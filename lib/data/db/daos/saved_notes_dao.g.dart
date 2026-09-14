// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_notes_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedNotesDaoMixin on DatabaseAccessor<AppDatabase> {
  $NoteFoldersTable get noteFolders => attachedDatabase.noteFolders;
  $SavedNotesTable get savedNotes => attachedDatabase.savedNotes;
  SavedNotesDaoManager get managers => SavedNotesDaoManager(this);
}

class SavedNotesDaoManager {
  final _$SavedNotesDaoMixin _db;
  SavedNotesDaoManager(this._db);
  $$NoteFoldersTableTableManager get noteFolders =>
      $$NoteFoldersTableTableManager(_db.attachedDatabase, _db.noteFolders);
  $$SavedNotesTableTableManager get savedNotes =>
      $$SavedNotesTableTableManager(_db.attachedDatabase, _db.savedNotes);
}
