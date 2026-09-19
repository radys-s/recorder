import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/subject_summary_service.dart';
import 'package:recorder/ai/syllabus.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';
import 'package:recorder/features/subjects/widgets/subject_overview.dart';

class _FakeSummary implements SubjectSummaryService {
  _FakeSummary(this.result);
  final SubjectSummaryResult result;
  final asked = <int>[];

  @override
  Future<SubjectSummaryResult> summarize(int subjectId) async {
    asked.add(subjectId);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

FilledButton _button(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(
    of: find.text('Shrnutí předmětu'),
    matching: find.byWidgetPredicate((w) => w is FilledButton),
  ),
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Unmounts inside the body; see `notes_library_screen_test.dart`.
  void uiTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<int> seed(WidgetTester tester, {bool plan = true}) async {
    return (await tester.runAsync(() async {
      final id = await db.savedNotesDao.createFolder('Počítačové sítě');
      if (plan) {
        await db.subjectsDao.replaceTopics(id, const [
          SyllabusTopicDraft(title: 'TCP/IP', monthFrom: 10),
          SyllabusTopicDraft(title: 'Adresace', monthFrom: 11),
          SyllabusTopicDraft(title: 'VLAN', monthFrom: 12),
        ], SyllabusSource.pasted);
      }
      return id;
    }))!;
  }

  Future<void> lesson(
    WidgetTester tester,
    int subject,
    DateTime at, {
    bool notes = true,
  }) async {
    await tester.runAsync(() async {
      final id = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Hodina',
          createdAt: at,
          subjectId: Value(subject),
        ),
      );
      if (notes) {
        await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
        await db.meetingNotesDao.markReady(id, 'Výpisky');
      }
    });
  }

  Future<void> show(
    WidgetTester tester,
    int subject, {
    VoidCallback? onOpenSettings,
    SubjectSummaryService? summary,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          if (summary != null)
            subjectSummaryServiceProvider.overrideWithValue(summary),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SubjectOverview(
              subjectId: subject,
              onOpenSettings: onOpenSettings ?? () {},
              now: DateTime(2026, 12, 10),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  uiTest('without a plan it points to where one is added', (tester) async {
    final subject = await seed(tester, plan: false);
    var opened = 0;
    await show(tester, subject, onOpenSettings: () => opened++);

    expect(find.text('Zatím bez plánu'), findsOneWidget);
    expect(find.text('Tematický plán'), findsNothing);
    await tester.tap(find.text('Přidat plán'));
    expect(opened, 1);

    // No výpisky yet: the summary has nothing to read.
    expect(_button(tester).onPressed, isNull);
    expect(
      find.text('Nejdřív vytvoř výpisky u hodin — shrnutí vychází z nich.'),
      findsOneWidget,
    );
  });

  uiTest('the plan as a timeline with the lessons that covered it',
      (tester) async {
    final subject = await seed(tester);
    await lesson(tester, subject, DateTime(2026, 10, 6));
    await lesson(tester, subject, DateTime(2026, 10, 20), notes: false);
    await lesson(tester, subject, DateTime(2026, 12, 2));
    await show(tester, subject);

    expect(find.text('Probráno 2 z 3'), findsOneWidget);
    expect(find.text('Chybí záznam: 1'), findsOneWidget);
    for (final title in ['TCP/IP', 'Adresace', 'VLAN']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Chybí záznam'), findsOneWidget);
    expect(find.text('Probráno'), findsNWidgets(2));
    // VLAN is both covered and where the plan is now.
    expect(find.text('Teď'), findsOneWidget);
    for (final date in ['6. 10.', '20. 10.', '2. 12.']) {
      expect(find.widgetWithText(ActionChip, date), findsOneWidget);
    }
    expect(_button(tester).onPressed, isNotNull);
    expect(
      find.text('1 hodina bez výpisků — do shrnutí se nezapočítají.'),
      findsOneWidget,
    );
  });

  uiTest('a written summary is announced with a way to open it',
      (tester) async {
    final subject = await seed(tester);
    await lesson(tester, subject, DateTime(2026, 10, 6));
    final fake = _FakeSummary(const SubjectSummaryResult.saved(7));
    await show(tester, subject, summary: fake);

    await tester.tap(find.text('Shrnutí předmětu'));
    await _settle(tester);

    expect(fake.asked, [subject]);
    expect(find.text('Shrnutí je uložené v poznámkách.'), findsOneWidget);
    expect(find.text('Otevřít'), findsOneWidget);
  });

  uiTest('a failed summary says why', (tester) async {
    final subject = await seed(tester);
    await lesson(tester, subject, DateTime(2026, 10, 6));
    await show(
      tester,
      subject,
      summary: _FakeSummary(
        const SubjectSummaryResult.failed('AI služby teď neodpovídají.'),
      ),
    );

    await tester.tap(find.text('Shrnutí předmětu'));
    await _settle(tester);

    expect(find.text('AI služby teď neodpovídají.'), findsOneWidget);
    // Not stuck on „Píšu shrnutí…": the button can be tried again.
    expect(_button(tester).onPressed, isNotNull);
  });
}
