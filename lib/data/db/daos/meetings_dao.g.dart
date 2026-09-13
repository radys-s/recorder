// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meetings_dao.dart';

// ignore_for_file: type=lint
mixin _$MeetingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $MeetingsTable get meetings => attachedDatabase.meetings;
  $TranscriptSegmentsTable get transcriptSegments =>
      attachedDatabase.transcriptSegments;
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
}
