// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drive_docs_dao.dart';

// ignore_for_file: type=lint
mixin _$DriveDocsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DriveDocsTable get driveDocs => attachedDatabase.driveDocs;
  DriveDocsDaoManager get managers => DriveDocsDaoManager(this);
}

class DriveDocsDaoManager {
  final _$DriveDocsDaoMixin _db;
  DriveDocsDaoManager(this._db);
  $$DriveDocsTableTableManager get driveDocs =>
      $$DriveDocsTableTableManager(_db.attachedDatabase, _db.driveDocs);
}
