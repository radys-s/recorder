import 'package:drift/drift.dart';

/// Which language Whisper is told the meeting is in.
///
/// [auto] maps to a null language code, which is what the app did before this
/// setting existed — so it is a real escape hatch rather than a new code path.
enum TranscriptLanguage {
  czech,
  english,
  auto;

  String? get code => switch (this) {
        TranscriptLanguage.czech => 'cs',
        TranscriptLanguage.english => 'en',
        TranscriptLanguage.auto => null,
      };

  String get label => switch (this) {
        TranscriptLanguage.czech => 'Čeština',
        TranscriptLanguage.english => 'Angličtina',
        TranscriptLanguage.auto => 'Automaticky',
      };
}

/// How much of the meeting the AI notes should cover.
enum NotesDepth {
  brief,
  standard,
  full;

  String get label => switch (this) {
        NotesDepth.brief => 'Jen to hlavní',
        NotesDepth.standard => 'Vyvážené',
        NotesDepth.full => 'Podrobné',
      };
}

/// App settings that have to survive a restart but are not secrets.
///
/// A single row, always id 0. The API key lives in the platform keystore
/// instead; everything else belongs in the database that is already the app's
/// persistence layer, rather than in a second storage mechanism.
class Preferences extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// Defaults are written as integer literals because `withDefault` needs a
  /// const expression and an enum's `.index` is not one. The names beside them
  /// are the contract: reorder either enum and these have to change too.
  IntColumn get transcriptLanguage =>
      intEnum<TranscriptLanguage>().withDefault(const Constant(0))(); // czech
  IntColumn get notesDepth =>
      intEnum<NotesDepth>().withDefault(const Constant(1))(); // standard
  BoolColumn get liveAnswersEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Whether a question the meeting itself cannot answer is looked up on the
  /// web.
  ///
  /// Off by default, and deliberately not folded into [liveAnswersEnabled]:
  /// turning it on sends a question derived from a private meeting to a search
  /// index. Only the question sentence ever leaves the device — never the
  /// transcript — but that is still a decision the user makes knowingly rather
  /// than discovers later.
  BoolColumn get webAnswersEnabled =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
