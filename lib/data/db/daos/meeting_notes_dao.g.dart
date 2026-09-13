// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meeting_notes_dao.dart';

// ignore_for_file: type=lint
mixin _$MeetingNotesDaoMixin on DatabaseAccessor<AppDatabase> {
  $MeetingNotesTable get meetingNotes => attachedDatabase.meetingNotes;
  MeetingNotesDaoManager get managers => MeetingNotesDaoManager(this);
}

class MeetingNotesDaoManager {
  final _$MeetingNotesDaoMixin _db;
  MeetingNotesDaoManager(this._db);
  $$MeetingNotesTableTableManager get meetingNotes =>
      $$MeetingNotesTableTableManager(_db.attachedDatabase, _db.meetingNotes);
}
