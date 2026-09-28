// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_cards_dao.dart';

// ignore_for_file: type=lint
mixin _$StudyCardsDaoMixin on DatabaseAccessor<AppDatabase> {
  $StudyCardsTable get studyCards => attachedDatabase.studyCards;
  StudyCardsDaoManager get managers => StudyCardsDaoManager(this);
}

class StudyCardsDaoManager {
  final _$StudyCardsDaoMixin _db;
  StudyCardsDaoManager(this._db);
  $$StudyCardsTableTableManager get studyCards =>
      $$StudyCardsTableTableManager(_db.attachedDatabase, _db.studyCards);
}
