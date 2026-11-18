import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/audio/recording_controller.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/meeting_detail/meeting_detail_screen.dart';

class _Recording extends RecordingController {
  _Recording(this.meetingId);
  final int? meetingId;
  @override
  RecordingState build() => meetingId == null
      ? const RecordingState()
      : RecordingState(
          isRecording: true,
          meetingId: meetingId,
          startedAt: DateTime(2026, 11, 18, 8),
        );
}

/// The player is the first thing under the tabs; it should be there only when
/// it can be used and the student is on the transcript.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
  });

  late AppDatabase db;

  /// Unmounts the screen and lets its timers run out before the database goes.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  Future<void> pump(
    WidgetTester tester, {
    required bool recording,
    int initialTab = 0,
    bool otherLessonRecording = false,
  }) async {
    // Wide enough for the test font (Ahem) in the chat bar.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title: 'Hodina 18.11. 08:00',
        createdAt: DateTime(2026, 11, 18, 8),
        endedAt: Value(recording ? null : DateTime(2026, 11, 18, 8, 45)),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          recordingControllerProvider.overrideWith(
            () => _Recording(
              recording
                  ? id
                  : otherLessonRecording
                  ? id + 1
                  : null,
            ),
          ),
        ],
        child: MaterialApp(
          home: MeetingDetailScreen(meetingId: id, initialTab: initialTab),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a finished lesson shows its player on the transcript', (
    tester,
  ) async {
    await pump(tester, recording: false);
    expect(find.text('Zvuk hodiny'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('while recording the unusable player is not shown', (
    tester,
  ) async {
    await pump(tester, recording: true);
    expect(find.text('Zvuk hodiny'), findsNothing);
    expect(
      find.text('Přehrávání bude dostupné po ukončení nahrávání.'),
      findsNothing,
    );
    await finish(tester);
  });

  testWidgets('notes start right under the tabs, without the idle player', (
    tester,
  ) async {
    await pump(tester, recording: false, initialTab: 1);
    expect(find.text('Zvuk hodiny'), findsNothing);
    await finish(tester);
  });

  testWidgets('switching to the notes folds the idle player away', (
    tester,
  ) async {
    await pump(tester, recording: false);
    await tester.tap(find.text('Poznámky'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Zvuk hodiny'), findsNothing);
    await finish(tester);
  });

  testWidgets('another lesson recording hides the player here too', (
    tester,
  ) async {
    await pump(tester, recording: false, otherLessonRecording: true);
    expect(find.text('Zvuk hodiny'), findsNothing);
    await finish(tester);
  });
}
