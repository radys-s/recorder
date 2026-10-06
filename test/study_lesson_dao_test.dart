import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/study_cards_dao.dart';
import 'package:recorder/data/db/tables/study_cards_table.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late int subject;
  late int other;
  final day = DateTime(2026, 9, 28, 10);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    subject = await db.savedNotesDao.createFolder('Sítě');
    other = await db.savedNotesDao.createFolder('Dějepis');
  });
  tearDown(() => db.close());

  Future<void> add(
    int subjectId,
    String front, {
    int? meetingId,
    DateTime? now,
  }) => db.studyCardsDao.addCards(
    subjectId,
    [StudyItem(front, 'odpověď', StudySource.terms)],
    meetingId: meetingId,
    now: now ?? day,
  );

  group('lesson scope', () {
    test('dueCards limited to one lesson', () async {
      await add(subject, 'A', meetingId: 1);
      await add(subject, 'B', meetingId: 1);
      await add(subject, 'C', meetingId: 2);
      await add(subject, 'D');

      final all = await db.studyCardsDao.dueCards(day, subjectId: subject);
      final one = await db.studyCardsDao.dueCards(
        day,
        subjectId: subject,
        meetingId: 1,
      );
      expect(all, hasLength(4));
      expect(one.map((c) => c.front), ['A', 'B']);
    });

    test('lesson scope never leaks across subjects', () async {
      await add(subject, 'A', meetingId: 1);
      await add(other, 'Z', meetingId: 1);
      final cards = await db.studyCardsDao.dueCards(
        day,
        subjectId: subject,
        meetingId: 1,
      );
      expect(cards.map((c) => c.front), ['A']);
    });

    test('watchLessonStats counts total and due, skips paused', () async {
      await add(subject, 'A', meetingId: 1);
      await add(subject, 'B', meetingId: 1);
      await add(subject, 'C', meetingId: 1);
      final cards = await db.studyCardsDao.dueCards(day, meetingId: 1);
      await db.studyCardsDao.setSuspended(cards.first.id, true);
      // One card is rescheduled to next week.
      await db.studyCardsDao.addCards(
        subject,
        [StudyItem('D', 'x', StudySource.terms)],
        meetingId: 1,
        now: day.add(const Duration(days: 7)),
      );

      final stats = await db.studyCardsDao.watchLessonStats(1, day).first;
      expect(stats.total, 4);
      expect(stats.due, 2);

      final none = await db.studyCardsDao.watchLessonStats(99, day).first;
      expect((none.total, none.due), (0, 0));
    });

    test(
      'watchLessonCounts is per lesson and omits lessons without cards',
      () async {
        await add(subject, 'A', meetingId: 1);
        await add(subject, 'B', meetingId: 1);
        await add(subject, 'C', meetingId: 2);
        await add(subject, 'manual'); // no lesson
        await add(other, 'Z', meetingId: 3);

        final counts = await db.studyCardsDao
            .watchLessonCounts(subject, day)
            .first;
        expect(counts.keys.toSet(), {1, 2});
        expect(counts[1]!.total, 2);
        expect(counts[1]!.due, 2);
        expect(counts[2]!.total, 1);
      },
    );
  });

  group('nextDueAfterToday', () {
    test('null when nothing is scheduled later', () async {
      await add(subject, 'A', meetingId: 1);
      expect(
        await db.studyCardsDao.nextDueAfterToday(day, subjectId: subject),
        isNull,
      );
    });

    test(
      'picks the earliest future card, within the requested scope',
      () async {
        final in3 = day.add(const Duration(days: 3));
        final in9 = day.add(const Duration(days: 9));
        await add(subject, 'A', meetingId: 1, now: in9);
        await add(subject, 'B', meetingId: 2, now: in3);
        await add(
          other,
          'Z',
          meetingId: 3,
          now: day.add(const Duration(days: 1)),
        );

        final subjectNext = await db.studyCardsDao.nextDueAfterToday(
          day,
          subjectId: subject,
        );
        expect(subjectNext, in3);

        final lessonNext = await db.studyCardsDao.nextDueAfterToday(
          day,
          subjectId: subject,
          meetingId: 1,
        );
        expect(lessonNext, in9);
      },
    );

    test('paused cards do not count', () async {
      final later = day.add(const Duration(days: 4));
      await add(subject, 'A', meetingId: 1, now: later);
      final card = (await db.studyCardsDao.dueCards(
        later,
        subjectId: subject,
      )).single;
      await db.studyCardsDao.setSuspended(card.id, true);
      expect(
        await db.studyCardsDao.nextDueAfterToday(day, subjectId: subject),
        isNull,
      );
    });
  });
}
