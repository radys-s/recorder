import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/lesson_reminders.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/lesson_reminder_service.dart';

/// Records what it was asked to schedule, and can refuse permission.
class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.allow = true});

  final bool allow;
  final scheduled = <PlannedReminder>[];
  int cancels = 0;
  int permissionAsks = 0;

  @override
  Future<bool> ensurePermission() async {
    permissionAsks++;
    return allow;
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async =>
      scheduled.add(reminder);
}

void main() {
  const mon = 1;
  const sun = 7;

  ReminderSlot slot(int weekday, int startMinute, {int id = 1, String? name}) =>
      ReminderSlot(
        subjectId: id,
        subjectName: name ?? 'Počítačové sítě',
        weekday: weekday,
        startMinute: startMinute,
      );

  group('planReminders', () {
    // Friday 2026-09-18, 08:00.
    final friday = DateTime(2026, 9, 18, 8);

    test('a five-minute lead can fall on the previous day', () {
      // Monday 00:02 — the reminder belongs to Sunday 23:57.
      final planned = planReminders(
        slots: [slot(mon, 2)],
        lead: const Duration(minutes: 5),
        from: friday,
      );

      expect(planned.first.at, DateTime(2026, 9, 20, 23, 57));
      expect(planned.first.at.weekday, sun);
    });

    test('a fortnight of a weekly slot is two reminders', () {
      final planned = planReminders(
        slots: [slot(mon, 8 * 60)],
        lead: Duration.zero,
        from: friday,
      );

      expect(planned.map((r) => r.at), [
        DateTime(2026, 9, 21, 8),
        DateTime(2026, 9, 28, 8),
      ]);
      expect(planned.first.title, 'Začíná Počítačové sítě');
    });

    test('a lesson earlier today is not reminded about again', () {
      final planned = planReminders(
        slots: [slot(5, 7 * 60)], // Friday 07:00, already past
        lead: Duration.zero,
        from: friday,
      );

      // The next two Fridays (the horizon includes day 14), not today's.
      expect(planned.map((r) => r.at), [
        DateTime(2026, 9, 25, 7),
        DateTime(2026, 10, 2, 7),
      ]);
    });

    test('two subjects at the same minute produce one reminder', () {
      final planned = planReminders(
        slots: [
          slot(mon, 8 * 60, id: 1, name: 'Čeština'),
          slot(mon, 8 * 60, id: 2, name: 'Dějepis'),
        ],
        lead: Duration.zero,
        from: friday,
      );

      expect(planned.length, 2); // two Mondays, not four
      expect(planned.every((r) => r.subjectId == 1), isTrue);
      expect(planned.map((r) => r.id).toSet().length, 2);
    });

    test('the cap holds, and keeps the soonest lessons', () {
      final slots = [
        for (var day = 1; day <= 7; day++)
          for (var hour = 8; hour < 14; hour++) slot(day, hour * 60),
      ];

      final planned = planReminders(
        slots: slots,
        lead: Duration.zero,
        from: friday,
        cap: 10,
      );

      expect(planned.length, 10);
      expect(planned.first.at, DateTime(2026, 9, 18, 9));
      for (var i = 1; i < planned.length; i++) {
        expect(planned[i].at.isAfter(planned[i - 1].at), isTrue);
      }
    });

    test('no timetable, no reminders', () {
      expect(
        planReminders(slots: const [], lead: Duration.zero, from: friday),
        isEmpty,
      );
    });
  });

  group('LessonReminderService', () {
    late AppDatabase db;
    final friday = DateTime(2026, 9, 18, 8);

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> seedTimetable() async {
      final subject = await db.savedNotesDao.createFolder('Čeština');
      await db.subjectsDao.addSlot(
        subjectId: subject,
        weekday: 1,
        startMinute: 8 * 60,
        endMinute: 8 * 60 + 45,
      );
    }

    LessonReminderService service(ReminderScheduler scheduler) =>
        LessonReminderService(db, scheduler, now: () => friday);

    test('off schedules nothing and clears what was there', () async {
      await seedTimetable();
      final scheduler = _FakeScheduler();

      expect(await service(scheduler).reschedule(), 0);
      expect(scheduler.cancels, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    test('turning it on asks, stores and schedules', () async {
      await seedTimetable();
      final scheduler = _FakeScheduler();

      final ok = await service(scheduler)
          .setReminder(LessonReminder.fiveMinutes);

      expect(ok, isTrue);
      expect(scheduler.permissionAsks, 1);
      expect(
        (await db.preferencesDao.current()).lessonReminder,
        LessonReminder.fiveMinutes,
      );
      expect(scheduler.scheduled.first.at, DateTime(2026, 9, 21, 7, 55));
    });

    test('a refused permission leaves the setting off', () async {
      await seedTimetable();
      final scheduler = _FakeScheduler(allow: false);

      final ok = await service(scheduler).setReminder(LessonReminder.atStart);

      expect(ok, isFalse);
      expect(
        (await db.preferencesDao.current()).lessonReminder,
        LessonReminder.off,
      );
      expect(scheduler.scheduled, isEmpty);
    });

    test('turning it off needs no permission', () async {
      final scheduler = _FakeScheduler(allow: false);

      expect(await service(scheduler).setReminder(LessonReminder.off), isTrue);
      expect(scheduler.permissionAsks, 0);
    });

    test('overlapping runs do not plan anything twice', () async {
      await seedTimetable();
      await db.preferencesDao.setLessonReminder(LessonReminder.atStart);
      final scheduler = _FakeScheduler();
      final s = service(scheduler);

      final counts = await Future.wait([s.reschedule(), s.reschedule()]);

      expect(counts, [2, 2]);
      expect(scheduler.scheduled.length, 2);
      expect(scheduler.cancels, 2);
    });

    test('a slot whose subject is gone is skipped', () async {
      final subject = await db.savedNotesDao.createFolder('Čeština');
      await db.subjectsDao.addSlot(
        subjectId: subject,
        weekday: 1,
        startMinute: 8 * 60,
        endMinute: 8 * 60 + 45,
      );
      await db.preferencesDao.setLessonReminder(LessonReminder.atStart);
      await db.subjectsDao.deleteSubject(subject);

      final scheduler = _FakeScheduler();
      expect(await service(scheduler).reschedule(), 0);
    });
  });
}
