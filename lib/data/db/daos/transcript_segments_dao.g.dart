// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_segments_dao.dart';

// ignore_for_file: type=lint
mixin _$TranscriptSegmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TranscriptSegmentsTable get transcriptSegments =>
      attachedDatabase.transcriptSegments;
  TranscriptSegmentsDaoManager get managers =>
      TranscriptSegmentsDaoManager(this);
}

class TranscriptSegmentsDaoManager {
  final _$TranscriptSegmentsDaoMixin _db;
  TranscriptSegmentsDaoManager(this._db);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.transcriptSegments,
      );
}
