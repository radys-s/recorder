// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subjects_dao.dart';

// ignore_for_file: type=lint
mixin _$SubjectsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SubjectsTable get subjects => attachedDatabase.subjects;
  $ContextCardsTable get contextCards => attachedDatabase.contextCards;
  $CardImagesTable get cardImages => attachedDatabase.cardImages;
  $MeetingCardsTable get meetingCards => attachedDatabase.meetingCards;
  $TimetableSlotsTable get timetableSlots => attachedDatabase.timetableSlots;
  $MeetingsTable get meetings => attachedDatabase.meetings;
  $SavedNotesTable get savedNotes => attachedDatabase.savedNotes;
  $ChatMessagesTable get chatMessages => attachedDatabase.chatMessages;
  SubjectsDaoManager get managers => SubjectsDaoManager(this);
}

class SubjectsDaoManager {
  final _$SubjectsDaoMixin _db;
  SubjectsDaoManager(this._db);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db.attachedDatabase, _db.subjects);
  $$ContextCardsTableTableManager get contextCards =>
      $$ContextCardsTableTableManager(_db.attachedDatabase, _db.contextCards);
  $$CardImagesTableTableManager get cardImages =>
      $$CardImagesTableTableManager(_db.attachedDatabase, _db.cardImages);
  $$MeetingCardsTableTableManager get meetingCards =>
      $$MeetingCardsTableTableManager(_db.attachedDatabase, _db.meetingCards);
  $$TimetableSlotsTableTableManager get timetableSlots =>
      $$TimetableSlotsTableTableManager(
        _db.attachedDatabase,
        _db.timetableSlots,
      );
  $$MeetingsTableTableManager get meetings =>
      $$MeetingsTableTableManager(_db.attachedDatabase, _db.meetings);
  $$SavedNotesTableTableManager get savedNotes =>
      $$SavedNotesTableTableManager(_db.attachedDatabase, _db.savedNotes);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db.attachedDatabase, _db.chatMessages);
}
