import 'package:drift/drift.dart';

/// Where a thematic plan came from. Stored by index, so new sources are
/// appended.
enum SyllabusSource {
  pasted,
  photo,
  pdf,
  ai;

  String get label => switch (this) {
    SyllabusSource.pasted => 'Vložený text',
    SyllabusSource.photo => 'Z fotky',
    SyllabusSource.pdf => 'Z PDF',
    SyllabusSource.ai => 'Odhad AI',
  };
}

/// One topic of a subject's thematic plan (tematický plán), in teaching order.
///
/// Months are 1–12 as the plan names them; a plan often gives none, and then
/// the topic's place in the school year follows from [ord].
class SyllabusTopics extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer()();
  IntColumn get ord => integer()();
  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get description => text().nullable()();

  /// Terms the topic uses, as a comma list.
  TextColumn get terms => text().nullable()();
  IntColumn get monthFrom => integer().nullable()();
  IntColumn get monthTo => integer().nullable()();
  IntColumn get source => intEnum<SyllabusSource>()();
  DateTimeColumn get createdAt => dateTime()();
}
