// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_notes_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedNotesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SubjectsTable get subjects => attachedDatabase.subjects;
  $SavedNotesTable get savedNotes => attachedDatabase.savedNotes;
  SavedNotesDaoManager get managers => SavedNotesDaoManager(this);
}

class SavedNotesDaoManager {
  final _$SavedNotesDaoMixin _db;
  SavedNotesDaoManager(this._db);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db.attachedDatabase, _db.subjects);
  $$SavedNotesTableTableManager get savedNotes =>
      $$SavedNotesTableTableManager(_db.attachedDatabase, _db.savedNotes);
}
