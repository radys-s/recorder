import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/answer_cards_dao.dart';
import 'daos/chat_messages_dao.dart';
import 'daos/meeting_notes_dao.dart';
import 'daos/meetings_dao.dart';
import 'daos/preferences_dao.dart';
import 'daos/saved_notes_dao.dart';
import 'daos/subjects_dao.dart';
import 'daos/transcript_segments_dao.dart';
import 'daos/upload_queue_dao.dart';
import 'tables/answer_cards_table.dart';
import 'tables/chat_messages_table.dart';
import 'tables/context_cards_table.dart';
import 'tables/meeting_notes_table.dart';
import 'tables/meetings_table.dart';
import 'tables/preferences_table.dart';
import 'tables/saved_notes_table.dart';
import 'tables/subjects_table.dart';
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
    Subjects,
    SavedNotes,
    ContextCards,
    CardImages,
    MeetingCards,
    TimetableSlots,
    ChatMessages,
  ],
  daos: [
    MeetingsDao,
    TranscriptSegmentsDao,
    UploadQueueDao,
    PreferencesDao,
    MeetingNotesDao,
    AnswerCardsDao,
    SavedNotesDao,
    SubjectsDao,
    ChatMessagesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// An arbitrary executor — `NativeDatabase.memory()` in tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 11;

  /// `createTable` always creates the table as it is *now*, so a column added
  /// in a later version must only be added when the table already existed
  /// before this upgrade — hence the `from >= N` guards, N being the version
  /// that created the table.
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
          if (from == 5) {
            await m.addColumn(answerCards, answerCards.basis);
          }
          if (from < 7) {
            if (from >= 5) await m.addColumn(answerCards, answerCards.sources);
            if (from >= 3) {
              await m.addColumn(preferences, preferences.webAnswersEnabled);
            }
          }
          if (from < 8 && from >= 3) {
            await m.addColumn(preferences, preferences.micSensitivity);
          }
          if (from < 9) {
            await m.createTable(subjects);
            await m.createTable(savedNotes);
          }
          if (from < 10) {
            if (from == 9) {
              await m.addColumn(subjects, subjects.rules);
              await m.addColumn(subjects, subjects.colorIndex);
              await m.addColumn(subjects, subjects.sortOrder);
            }
            await m.addColumn(meetings, meetings.subjectId);
            await m.addColumn(meetings, meetings.rules);
            if (from >= 5) {
              await m.addColumn(answerCards, answerCards.detail);
              await m.addColumn(answerCards, answerCards.cardId);
            }
            if (from >= 3) {
              await m.addColumn(preferences, preferences.globalRules);
            }
            await m.createTable(contextCards);
            await m.createTable(cardImages);
            await m.createTable(meetingCards);
            await m.createTable(timetableSlots);
            await m.createTable(chatMessages);
          }
          if (from < 11 && from >= 3) {
            // Automatic sensitivity arrived in v11; existing installs switch
            // to it once, and a manual choice made afterwards sticks.
            await customStatement('UPDATE preferences SET mic_sensitivity = 3');
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
