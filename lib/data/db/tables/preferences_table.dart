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
    NotesDepth.standard => 'Shrnutí, probírané body, rozhodnutí a úkoly.',
    NotesDepth.detailed => 'Každé téma zvlášť s hlavními argumenty a čísly.',
    NotesDepth.full => 'Téměř vše, co zaznělo, včetně námitek a příkladů.',
  };

  /// The same depth described for výpisky from a lesson.
  String get lessonDescription => switch (this) {
    NotesDepth.keywords => 'Pár hesel s krátkou definicí.',
    NotesDepth.brief => 'Téma a nejdůležitější body.',
    NotesDepth.standard => 'Pojmy, příklady a co může být v testu.',
    NotesDepth.detailed => 'Každé podtéma zvlášť, s pojmy a souvislostmi.',
    NotesDepth.full => 'Všechno z hodiny, nic nevynecháno.',
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

/// The kind of school, which sets the level the AI writes at.
///
/// Stored by index, so new kinds are appended.
enum SchoolType {
  primary,
  gymnasium,
  secondaryTechnical,
  vocational,
  higherVocational,
  university,
  other;

  String get label => switch (this) {
    SchoolType.primary => 'ZŠ',
    SchoolType.gymnasium => 'Gymnázium',
    SchoolType.secondaryTechnical => 'SOŠ',
    SchoolType.vocational => 'SOU',
    SchoolType.higherVocational => 'VOŠ',
    SchoolType.university => 'VŠ',
    SchoolType.other => 'Jiná',
  };
}

/// How long a finished lesson's audio is kept before it is deleted.
///
/// A 45-minute lesson is about 85 MB of 16 kHz mono WAV, so a school week
/// fills a gigabyte or two. The transcript, the výpisky and everything else
/// stay; only the chunk files go. Stored by index, so new steps are appended.
enum AudioRetention {
  oneDay,
  sevenDays,
  thirtyDays,
  never;

  static const ordered = [oneDay, sevenDays, thirtyDays, never];

  /// Null for [never], which is the whole point of that value.
  Duration? get keepFor => switch (this) {
    AudioRetention.oneDay => const Duration(days: 1),
    AudioRetention.sevenDays => const Duration(days: 7),
    AudioRetention.thirtyDays => const Duration(days: 30),
    AudioRetention.never => null,
  };

  String get label => switch (this) {
    AudioRetention.oneDay => '1 den',
    AudioRetention.sevenDays => '7 dní',
    AudioRetention.thirtyDays => '30 dní',
    AudioRetention.never => 'Nikdy',
  };
}

/// How long before a timetabled lesson the phone reminds the student.
///
/// Stored by index, so new steps are appended. [off] is the default: a
/// reminder needs notification permission, and asking for it at first launch
/// — before the student has a timetable at all — is a prompt nobody can
/// answer sensibly. The switch in Nastavení asks at the moment it can explain
/// what for.
enum LessonReminder {
  off,
  fiveMinutes,
  atStart;

  static const ordered = [off, fiveMinutes, atStart];

  /// How far ahead of the lesson the notification fires. Null for [off].
  Duration? get lead => switch (this) {
    LessonReminder.off => null,
    LessonReminder.fiveMinutes => const Duration(minutes: 5),
    LessonReminder.atStart => Duration.zero,
  };

  String get label => switch (this) {
    LessonReminder.off => 'Vypnuto',
    LessonReminder.fiveMinutes => '5 minut předem',
    LessonReminder.atStart => 'Při začátku',
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

  /// A Gemini model id picked in Settings; null follows the app's default.
  TextColumn get geminiModelOverride => text().nullable()();

  /// The first-run guide was closed by the user.
  BoolColumn get onboardingDismissed =>
      boolean().withDefault(const Constant(false))();

  /// Lesson transcripts get a second look that fixes misheard subject terms.
  BoolColumn get contextCorrection =>
      boolean().withDefault(const Constant(true))();

  /// The student's course: school, kind of school, field and year. All
  /// optional; filled in, they tell every prompt the level of the lessons.
  TextColumn get schoolName => text().nullable()();
  IntColumn get schoolType => intEnum<SchoolType>().nullable()();
  TextColumn get studyField => text().nullable()();
  IntColumn get studyYear => integer().nullable()();

  /// How long a finished lesson's audio is kept. The transcript is never
  /// touched by this.
  IntColumn get audioRetention =>
      intEnum<AudioRetention>().withDefault(const Constant(1))(); // sevenDays

  /// Whether the phone says a timetabled lesson is about to start, and when.
  IntColumn get lessonReminder =>
      intEnum<LessonReminder>().withDefault(const Constant(0))(); // off

  @override
  Set<Column> get primaryKey => {id};
}
