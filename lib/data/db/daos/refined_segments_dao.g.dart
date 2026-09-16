// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refined_segments_dao.dart';

// ignore_for_file: type=lint
mixin _$RefinedSegmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RefinedSegmentsTable get refinedSegments => attachedDatabase.refinedSegments;
  RefinedSegmentsDaoManager get managers => RefinedSegmentsDaoManager(this);
}

class RefinedSegmentsDaoManager {
  final _$RefinedSegmentsDaoMixin _db;
  RefinedSegmentsDaoManager(this._db);
  $$RefinedSegmentsTableTableManager get refinedSegments =>
      $$RefinedSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.refinedSegments,
      );
}
