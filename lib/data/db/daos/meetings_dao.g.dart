// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meetings_dao.dart';

// ignore_for_file: type=lint
mixin _$MeetingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $MeetingsTable get meetings => attachedDatabase.meetings;
  $TranscriptSegmentsTable get transcriptSegments =>
      attachedDatabase.transcriptSegments;
  $UploadQueueTable get uploadQueue => attachedDatabase.uploadQueue;
  $AnswerCardsTable get answerCards => attachedDatabase.answerCards;
  $MeetingNotesTable get meetingNotes => attachedDatabase.meetingNotes;
  $SavedNotesTable get savedNotes => attachedDatabase.savedNotes;
  MeetingsDaoManager get managers => MeetingsDaoManager(this);
}

class MeetingsDaoManager {
  final _$MeetingsDaoMixin _db;
  MeetingsDaoManager(this._db);
  $$MeetingsTableTableManager get meetings =>
      $$MeetingsTableTableManager(_db.attachedDatabase, _db.meetings);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.transcriptSegments,
      );
  $$UploadQueueTableTableManager get uploadQueue =>
      $$UploadQueueTableTableManager(_db.attachedDatabase, _db.uploadQueue);
  $$AnswerCardsTableTableManager get answerCards =>
      $$AnswerCardsTableTableManager(_db.attachedDatabase, _db.answerCards);
  $$MeetingNotesTableTableManager get meetingNotes =>
      $$MeetingNotesTableTableManager(_db.attachedDatabase, _db.meetingNotes);
  $$SavedNotesTableTableManager get savedNotes =>
      $$SavedNotesTableTableManager(_db.attachedDatabase, _db.savedNotes);
}
