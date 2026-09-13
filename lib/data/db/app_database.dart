import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/answer_cards_dao.dart';
import 'daos/meeting_notes_dao.dart';
import 'daos/meetings_dao.dart';
import 'daos/preferences_dao.dart';
import 'daos/transcript_segments_dao.dart';
import 'daos/upload_queue_dao.dart';
import 'tables/answer_cards_table.dart';
import 'tables/meeting_notes_table.dart';
import 'tables/meetings_table.dart';
import 'tables/preferences_table.dart';
import 'tables/transcript_segments_table.dart';
import 'tables/upload_queue_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Meetings,
    TranscriptSegments,
    UploadQueue,
    Preferences,
    MeetingNotes,
    AnswerCards,
  ],
  daos: [
    MeetingsDao,
    TranscriptSegmentsDao,
    UploadQueueDao,
    PreferencesDao,
    MeetingNotesDao,
    AnswerCardsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(meetings, meetings.interrupted);
          }
          if (from < 3) {
            await m.createTable(preferences);
          }
          if (from < 4) {
            await m.createTable(meetingNotes);
          }
          if (from < 5) {
            await m.createTable(answerCards);
          }
          if (from < 6) {
            await m.addColumn(answerCards, answerCards.basis);
          }
          if (from < 7) {
            await m.addColumn(answerCards, answerCards.sources);
            await m.addColumn(preferences, preferences.webAnswersEnabled);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'recorder.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

/// App-wide singleton so the recording controller and queue worker (both
/// outside the widget tree) can share the same connection as the UI.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
