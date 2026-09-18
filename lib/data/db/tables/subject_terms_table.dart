import 'package:drift/drift.dart';

/// Where a word in a subject's vocabulary came from. Stored by index, so new
/// sources are appended.
enum TermSource {
  manual,
  correction,
  card,
  notes,
  alias;

  String get label => switch (this) {
    TermSource.manual => 'Přidáno ručně',
    TermSource.correction => 'Z opravy přepisu',
    TermSource.card => 'Z karty',
    TermSource.notes => 'Z výpisků',
    TermSource.alias => 'Slyšená podoba',
  };
}

/// Words a subject uses — names, terms — that the transcription should get
/// right. A row with [heard] is a correction: Whisper wrote [heard], the
/// lesson meant [term].
class SubjectTerms extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer()();
  TextColumn get term => text().withLength(min: 1, max: 80)();
  TextColumn get heard => text().nullable()();
  IntColumn get source => intEnum<TermSource>()();

  /// How often the term turned up in a transcript; ranks the vocabulary.
  IntColumn get uses => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}
