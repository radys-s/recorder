// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'answer_cards_dao.dart';

// ignore_for_file: type=lint
mixin _$AnswerCardsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AnswerCardsTable get answerCards => attachedDatabase.answerCards;
  AnswerCardsDaoManager get managers => AnswerCardsDaoManager(this);
}

class AnswerCardsDaoManager {
  final _$AnswerCardsDaoMixin _db;
  AnswerCardsDaoManager(this._db);
  $$AnswerCardsTableTableManager get answerCards =>
      $$AnswerCardsTableTableManager(_db.attachedDatabase, _db.answerCards);
}
