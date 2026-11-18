import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/recording_controller.dart';
import 'package:recorder/core/theme.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/features/meeting_detail/meeting_detail_screen.dart';
import 'package:recorder/features/meeting_detail/transcript_fix.dart';
import 'package:recorder/features/meeting_detail/widgets/meeting_notes_tab.dart';
import 'package:recorder/features/settings/privacy_section.dart';

class _Idle extends RecordingController {
  @override
  RecordingState build() => const RecordingState();
}

void main() {
  late AppDatabase db;
  late int id;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    id = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title:
            'Velmi dlouhý název skutečně složité syntetické vyučovací hodiny',
        createdAt: DateTime(2026, 10, 6),
        endedAt: Value(DateTime(2026, 10, 6, 10)),
      ),
    );
    await db.transcriptSegmentsDao.insertSegment(
      TranscriptSegmentsCompanion.insert(
        meetingId: id,
        sequence: 0,
        startMs: 0,
        endMs: 3000,
        localAudioPath: 'recordings/synthetic-missing.wav',
        status: SegmentStatus.transcribed,
        content: Value('Syntetický přepis s delšími větami. ' * 20),
        createdAt: DateTime(2026, 10, 6),
      ),
    );
    await db.meetingNotesDao.markGenerating(
      id,
      NotesDepth.standard,
      'synthetic',
    );
    await db.meetingNotesDao.markReady(
      id,
      '- Pouze syntetické výpisky.\n' * 15,
    );
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    bool keyboard = false,
    bool outdated = false,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    if (keyboard) tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          recordingControllerProvider.overrideWith(_Idle.new),
          if (outdated)
            transcriptEditedAtProvider.overrideWith(
              (ref) => {id: DateTime(2030)},
            ),
        ],
        child: MaterialApp(
          theme: appLightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    // Let SQLite streams deliver without assuming a fast host or waiting for
    // an indefinitely running progress animation to settle.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets(
    'lesson detail keeps send reachable with 200% text and keyboard',
    (tester) async {
      await pump(tester, MeetingDetailScreen(meetingId: id), keyboard: true);
      await tester.tap(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Vysvětli delší syntetickou otázku?',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Odeslat').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Skrýt klávesnici').hitTestable(), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'outdated notes and generation controls fit a narrow large-text screen',
    (tester) async {
      await pump(
        tester,
        Scaffold(body: MeetingNotesTab(meetingId: id)),
        outdated: true,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('Poznámky jsou ze starší verze přepisu.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Upravit poznámky'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Hloubka poznámek'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'failed notes retain readable previous content and a recovery action',
    (tester) async {
      await db.meetingNotesDao.markFailed(
        id,
        'Syntetický výpadek sítě. Zkus to znovu.',
      );
      await pump(tester, Scaffold(body: MeetingNotesTab(meetingId: id)));
      expect(tester.takeException(), isNull);
      expect(
        find.text('Syntetický výpadek sítě. Zkus to znovu.'),
        findsOneWidget,
      );
      expect(find.text('Upravit poznámky'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('backup and text export are distinguished without clipping', (
    tester,
  ) async {
    await pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: PrivacySection())),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Záloha včetně zvuku'), findsOneWidget);
    expect(find.text('Exportovat texty'), findsOneWidget);
    await unmount(tester);
  });
}
