import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/preferences_table.dart';

part 'preferences_dao.g.dart';

/// The single settings row, id [_rowId].
///
/// Every accessor seeds the row first, so a fresh install and an upgrade from
/// a schema that had no preferences behave identically — nothing anywhere else
/// has to remember to create it.
@DriftAccessor(tables: [Preferences])
class PreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$PreferencesDaoMixin {
  PreferencesDao(super.db);

  static const _rowId = 0;

  /// A new install listens automatically. The column default stays medium,
  /// because changing a default in SQLite means rebuilding the table.
  Future<void> _ensureRow() async {
    await into(preferences).insert(
      const PreferencesCompanion(
        id: Value(_rowId),
        micSensitivity: Value(MicSensitivity.auto),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Watched, so flipping a setting updates every screen without a refresh.
  Stream<Preference> watch() async* {
    await _ensureRow();
    yield* (select(
      preferences,
    )..where((t) => t.id.equals(_rowId))).watchSingle();
  }

  /// One-shot read for code outside the widget tree — the queue worker asks
  /// for this per chunk, which is a local sqlite read every ~25 seconds.
  Future<Preference> current() async {
    await _ensureRow();
    return (select(preferences)..where((t) => t.id.equals(_rowId))).getSingle();
  }

  Future<void> _write(PreferencesCompanion patch) async {
    await _ensureRow();
    await (update(preferences)..where((t) => t.id.equals(_rowId))).write(patch);
  }

  Future<void> setTranscriptLanguage(TranscriptLanguage value) =>
      _write(PreferencesCompanion(transcriptLanguage: Value(value)));

  Future<void> setNotesDepth(NotesDepth value) =>
      _write(PreferencesCompanion(notesDepth: Value(value)));

  Future<void> setLiveAnswersEnabled(bool value) =>
      _write(PreferencesCompanion(liveAnswersEnabled: Value(value)));

  Future<void> setWebAnswersEnabled(bool value) =>
      _write(PreferencesCompanion(webAnswersEnabled: Value(value)));

  Future<void> setMicSensitivity(MicSensitivity value) =>
      _write(PreferencesCompanion(micSensitivity: Value(value)));

  Future<void> setOnboardingDismissed(bool value) =>
      _write(PreferencesCompanion(onboardingDismissed: Value(value)));

  Future<void> setAudioRetention(AudioRetention value) =>
      _write(PreferencesCompanion(audioRetention: Value(value)));

  Future<void> setLessonReminder(LessonReminder value) =>
      _write(PreferencesCompanion(lessonReminder: Value(value)));

  /// A new client id belongs to a different Google Cloud project, so the
  /// account signed in through the old one is forgotten with it.
  Future<void> setGoogleClientId(String? value) => _write(
    PreferencesCompanion(
      googleClientId: Value(value),
      googleAccountEmail: const Value(null),
    ),
  );

  Future<void> setGoogleAccountEmail(String? value) =>
      _write(PreferencesCompanion(googleAccountEmail: Value(value)));

  Future<void> setDriveSyncEnabled(bool value) =>
      _write(PreferencesCompanion(driveSyncEnabled: Value(value)));

  Future<void> setDriveIncludeTranscripts(bool value) =>
      _write(PreferencesCompanion(driveIncludeTranscripts: Value(value)));

  Future<void> setDriveFolderId(String? value) =>
      _write(PreferencesCompanion(driveFolderId: Value(value)));

  Future<void> setContextCorrection(bool value) =>
      _write(PreferencesCompanion(contextCorrection: Value(value)));

  /// Gemini model picked in Settings; null or blank returns to the default.
  Future<void> setGeminiModelOverride(String? value) {
    final trimmed = value?.trim() ?? '';
    return _write(
      PreferencesCompanion(
        geminiModelOverride: Value(trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  /// Rules for every lesson; blank clears them.
  /// Where and what the student studies; blanks clear, a year outside 1–10
  /// is dropped.
  Future<void> setStudyProfile({
    String? schoolName,
    SchoolType? schoolType,
    String? studyField,
    int? studyYear,
  }) {
    String? clean(String? v) {
      final t = v?.trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return _write(
      PreferencesCompanion(
        schoolName: Value(clean(schoolName)),
        schoolType: Value(schoolType),
        studyField: Value(clean(studyField)),
        studyYear: Value(
          studyYear != null && studyYear >= 1 && studyYear <= 10
              ? studyYear
              : null,
        ),
      ),
    );
  }

  Future<void> setGlobalRules(String? value) {
    final trimmed = value?.trim() ?? '';
    return _write(
      PreferencesCompanion(
        globalRules: Value(trimmed.isEmpty ? null : trimmed),
      ),
    );
  }
}
