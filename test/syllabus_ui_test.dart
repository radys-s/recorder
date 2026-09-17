import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/syllabus.dart';
import 'package:recorder/ai/syllabus_import_service.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';
import 'package:recorder/features/subjects/syllabus_import_screen.dart';
import 'package:recorder/features/subjects/widgets/lesson_context_strip.dart';
import 'package:recorder/features/subjects/widgets/subject_syllabus.dart';

class _FakeImport implements SyllabusImportService {
  final courses = <String>[];

  @override
  Future<SyllabusImport> fromText(String text, {required String course}) async {
    courses.add(course);
    return const SyllabusImport(
      topics: [
        SyllabusTopicDraft(title: 'Model OSI', terms: ['OSI'], monthFrom: 9),
        SyllabusTopicDraft(title: 'Směrování', monthFrom: 11, monthTo: 12),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SyllabusTopic _topic(int id, String title, {int? from, int? to, int ord = 0}) =>
    SyllabusTopic(
      id: id,
      subjectId: 1,
      ord: ord,
      title: title,
      monthFrom: from,
      monthTo: to,
      source: SyllabusSource.pasted,
      createdAt: DateTime(2026),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('labels', () {
    test('month range', () {
      expect(monthRangeLabel(null, null), isNull);
      expect(monthRangeLabel(9, null), 'září');
      expect(monthRangeLabel(9, 9), 'září');
      expect(monthRangeLabel(11, 1), 'listopad–leden');
    });

    test('topic count', () {
      expect(topicCount(1), '1 téma');
      expect(topicCount(3), '3 témata');
      expect(topicCount(5), '5 témat');
    });
  });

  test('a picked topic wins over the date', () {
    final topics = [
      _topic(1, 'OSI', from: 9, to: 10),
      _topic(2, 'Směrování', from: 11, to: 12, ord: 1),
    ];
    Meeting meeting({int? topicId}) => Meeting(
      id: 1,
      title: 'Hodina',
      createdAt: DateTime(2026, 9, 20),
      interrupted: false,
      topicId: topicId,
    );
    expect(lessonTopic(meeting(), topics)!.title, 'OSI');
    expect(lessonTopic(meeting(topicId: 2), topics)!.title, 'Směrování');
    expect(lessonTopic(meeting(topicId: 99), topics)!.title, 'OSI');
    expect(lessonTopic(meeting(), const []), isNull);
  });

  test('updateTopic edits in place and keeps the lesson link', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ps = await db.savedNotesDao.createFolder('PS');
    await db.subjectsDao.replaceTopics(ps, const [
      SyllabusTopicDraft(title: 'OSI'),
    ], SyllabusSource.ai);
    final id = (await db.subjectsDao.topics(ps)).single.id;

    await db.subjectsDao.updateTopic(
      id,
      const SyllabusTopicDraft(
        title: ' Model OSI ',
        terms: ['OSI', 'vrstvy'],
        monthFrom: 9,
        monthTo: 10,
      ),
    );
    final t = (await db.subjectsDao.topic(id))!;
    expect(t.title, 'Model OSI');
    expect(t.terms, 'OSI, vrstvy');
    expect((t.monthFrom, t.monthTo), (9, 10));
    expect(
      () =>
          db.subjectsDao.updateTopic(id, const SyllabusTopicDraft(title: ' ')),
      throwsArgumentError,
    );
  });

  group('widgets', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    /// Unmounts inside the body; see `notes_library_screen_test.dart`.
    void uiTest(String description, WidgetTesterCallback body) {
      testWidgets(description, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    uiTest('review screen saves the read plan', (tester) async {
      final fake = _FakeImport();
      final ps = await tester.runAsync(
        () => db.savedNotesDao.createFolder('PS'),
      );
      final subject = (await tester.runAsync(
        () => db.subjectsDao.subject(ps!),
      ))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            syllabusImportServiceProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  SyllabusImportScreen.route(subject: subject, text: '1. OSI'),
                ),
                child: const Text('Otevřít'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Otevřít'));
      await _settle(tester);

      expect(fake.courses.single, contains('PS'));
      expect(find.text('Model OSI'), findsOneWidget);
      expect(find.text('Směrování'), findsOneWidget);

      await tester.tap(find.text('Uložit 2 témata'));
      await _settle(tester);
      final saved = await tester.runAsync(() => db.subjectsDao.topics(ps!));
      expect(saved!.map((t) => t.title), ['Model OSI', 'Směrování']);
      expect(saved.first.source, SyllabusSource.pasted);
    });

    uiTest('subject section marks the current topic', (tester) async {
      final ps = await tester.runAsync(
        () => db.savedNotesDao.createFolder('PS'),
      );
      await tester.runAsync(
        () => db.subjectsDao.replaceTopics(ps!, const [
          SyllabusTopicDraft(title: 'OSI', monthFrom: 9, monthTo: 10),
          SyllabusTopicDraft(title: 'Směrování', monthFrom: 11, monthTo: 12),
        ], SyllabusSource.ai),
      );
      final subject = (await tester.runAsync(
        () => db.subjectsDao.subject(ps!),
      ))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SubjectSyllabus(
                  subject: subject,
                  now: DateTime(2026, 11, 5),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('2 témata · odhad AI'), findsOneWidget);
      expect(find.text('listopad–prosinec · teď'), findsOneWidget);
      expect(find.text('září–říjen'), findsOneWidget);
    });

    uiTest('topic picker returns automatic or a topic', (tester) async {
      final results = <({int? id})?>[];
      final topics = [
        _topic(1, 'OSI', from: 9),
        _topic(2, 'Směrování', from: 11, ord: 1),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showModalBottomSheet<({int? id})>(
                    context: context,
                    builder: (_) => TopicPickerSheet(
                      topics: topics,
                      selectedId: 2,
                      date: DateTime(2026, 9, 3),
                    ),
                  ),
                ),
                child: const Text('Téma'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Téma'));
      await _settle(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Směrování'));
      await _settle(tester);

      await tester.tap(find.text('Téma'));
      await _settle(tester);
      await tester.tap(find.text('Automaticky'));
      await _settle(tester);

      expect(results, [(id: 2), (id: null)]);
    });
  });
}
