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
///
/// Stored by index, so new depths are appended rather than slotted in where
/// they belong; [ordered] is the order a picker shows them in. [full] kept its
/// index when [detailed] took over the name „Podrobné".
enum NotesDepth {
  brief,
  standard,
  full,
  detailed,
  keywords;

  static const ordered = [keywords, brief, standard, detailed, full];

  String get label => switch (this) {
        NotesDepth.keywords => 'Heslovitě',
        NotesDepth.brief => 'Jen to hlavní',
        NotesDepth.standard => 'Vyvážené',
        NotesDepth.detailed => 'Podrobné',
        NotesDepth.full => 'Kompletní',
      };

  String get description => switch (this) {
        NotesDepth.keywords => 'Pár hesel: rozhodnutí, úkoly, termíny.',
        NotesDepth.brief => 'Krátký seznam toho, co padlo a kdo co udělá.',
        NotesDepth.standard =>
          'Shrnutí, probírané body, rozhodnutí a úkoly.',
        NotesDepth.detailed =>
          'Každé téma zvlášť s hlavními argumenty a čísly.',
        NotesDepth.full => 'Téměř vše, co zaznělo, včetně námitek a příkladů.',
      };
}

/// How eagerly quiet audio is taken for speech.
///
/// One setting over several thresholds — see `SensitivityProfile` — because the
/// user's question is "does it hear a quiet meeting", not which of five
/// numbers happens to be in the way. [auto] measures the room as the recording
/// starts and keeps following it.
enum MicSensitivity {
  low,
  medium,
  high,
  auto;

  static const ordered = [auto, low, medium, high];

  String get label => switch (this) {
        MicSensitivity.low => 'Málo',
        MicSensitivity.medium => 'Středně',
        MicSensitivity.high => 'Hodně',
        MicSensitivity.auto => 'Automaticky',
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

  IntColumn get micSensitivity =>
      intEnum<MicSensitivity>().withDefault(const Constant(1))(); // medium

  /// How the AI should answer everywhere, unless a subject or lesson says
  /// otherwise.
  TextColumn get globalRules => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
