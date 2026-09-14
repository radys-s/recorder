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

  Future<void> _ensureRow() async {
    await into(preferences).insertOnConflictUpdate(
      const PreferencesCompanion(id: Value(_rowId)),
    );
  }

  /// Watched, so flipping a setting updates every screen without a refresh.
  Stream<Preference> watch() async* {
    await _ensureRow();
    yield* (select(preferences)..where((t) => t.id.equals(_rowId)))
        .watchSingle();
  }

  /// One-shot read for code outside the widget tree — the queue worker asks
  /// for this per chunk, which is a local sqlite read every ~25 seconds.
  Future<Preference> current() async {
    await _ensureRow();
    return (select(preferences)..where((t) => t.id.equals(_rowId)))
        .getSingle();
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
}
