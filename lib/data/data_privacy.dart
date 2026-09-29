import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../core/paths.dart';
import '../core/redaction.dart';
import '../core/photo_files.dart';
import 'db/app_database.dart';
import 'db/tables/preferences_table.dart';
import 'secure/api_key_store.dart';

/// Everything the database holds, as JSON-ready maps keyed by table name.
///
/// API keys live in the Keychain, never here, so an export shared by mistake
/// cannot leak them. Audio and photos stay out too: they can run into
/// gigabytes and the transcripts and photo texts already carry their content.
Future<Map<String, Object?>> exportAllData(
  AppDatabase db, {
  required DateTime now,
}) async {
  final tables = <String, Object?>{};
  for (final table in db.allTables) {
    final rows = await db.select(table).get();
    tables[table.actualTableName] = [
      for (final row in rows)
        if (row is DataClass) _redactErrors(row.toJson()) else row.toString(),
    ];
  }
  return {
    'app': 'Aftermind',
    'exportedAt': now.toIso8601String(),
    'schemaVersion': db.schemaVersion,
    'tables': tables,
  };
}

/// Error columns come from servers and exceptions, so they are the one place a
/// secret could have slipped into a row written before redaction existed.
Map<String, dynamic> _redactErrors(Map<String, dynamic> json) => {
  for (final e in json.entries)
    e.key: e.key.toLowerCase().endsWith('error') && e.value is String
        ? redactSecrets(e.value as String)
        : e.value,
};

/// Removes everything the app keeps: every database row, recordings, photos,
/// the stored keys and the Google sign-in. What is left is a fresh install
/// that asks for consent again.
///
/// The Google grant is revoked first, while its token still exists; a revoke
/// that fails (offline) must not stop the rest.
class DataWiper {
  DataWiper(
    this._db, {
    required this.docsPath,
    required this.keyStores,
    required this.signOutGoogle,
    required this.cancelReminders,
  });

  final AppDatabase _db;
  final Future<String> Function() docsPath;
  final List<ApiKeyStore> keyStores;
  final Future<void> Function() signOutGoogle;
  final Future<void> Function() cancelReminders;

  Future<void> wipe() async {
    try {
      await signOutGoogle();
    } catch (_) {}
    try {
      await cancelReminders();
    } catch (_) {}

    await _db.transaction(() async {
      for (final table in _db.allTables) {
        await _db.delete(table).go();
      }
      // Re-seeded in the same transaction, so nothing watching the settings
      // ever sees them missing.
      await _db
          .into(_db.preferences)
          .insert(
            const PreferencesCompanion(
              id: Value(0),
              micSensitivity: Value(MicSensitivity.auto),
            ),
          );
    });

    final docs = await docsPath();
    for (final dir in const [
      kRecordingsDirName,
      kPhotosDirName,
      kCardPhotosDirName,
    ]) {
      final d = Directory(p.join(docs, dir));
      if (await d.exists()) await d.delete(recursive: true);
    }

    for (final store in keyStores) {
      await store.delete();
    }
  }
}
