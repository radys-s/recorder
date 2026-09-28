import 'package:drift/drift.dart';

/// Where a study card came from. Stored by index, so new sources are appended.
enum StudySource {
  terms,
  remember,
  quiz,
  manual;

  String get label => switch (this) {
    StudySource.terms => 'Klíčový pojem',
    StudySource.remember => 'Co si zapamatovat',
    StudySource.quiz => 'Chyba z testu',
    StudySource.manual => 'Přidáno ručně',
  };
}

/// One question–answer pair the student reviews on a spaced schedule.
///
/// [frontKey] is the question folded without case and diacritics; together
/// with the subject it keeps the same question from being added twice.
class StudyCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer()();
  IntColumn get meetingId => integer().nullable()();
  IntColumn get noteId => integer().nullable()();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get frontKey => text()();
  IntColumn get source => intEnum<StudySource>()();
  RealColumn get ease => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueAt => dateTime()();
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {subjectId, frontKey},
  ];
}
