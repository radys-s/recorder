import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/subjects/timetable.dart';

TimetableSlot _slot(int id, int subjectId, int weekday, String from, String to) {
  int minute(String hm) {
    final [h, m] = hm.split(':').map(int.parse).toList();
    return h * 60 + m;
  }

  return TimetableSlot(
    id: id,
    subjectId: subjectId,
    weekday: weekday,
    startMinute: minute(from),
    endMinute: minute(to),
  );
}

// 2026-09-14 is a Monday.
DateTime _mon(int h, int m) => DateTime(2026, 9, 14, h, m);

void main() {
  group('pickSubjectForNow', () {
    test('a running slot wins', () {
      final slots = [_slot(1, 10, 1, '8:00', '8:45')];
      expect(pickSubjectForNow(slots, _mon(8, 30)), 10);
      expect(pickSubjectForNow(slots, _mon(8, 0)), 10);
      expect(pickSubjectForNow(slots, _mon(8, 45)), isNull);
    });

    test('a slot starting within 10 minutes is picked, 11 is not', () {
      final slots = [_slot(1, 10, 1, '8:00', '8:45')];
      expect(pickSubjectForNow(slots, _mon(7, 50)), 10);
      expect(pickSubjectForNow(slots, _mon(7, 49)), isNull);
    });

    test('other weekdays do not count', () {
      final slots = [_slot(1, 10, 2, '8:00', '8:45')];
      expect(pickSubjectForNow(slots, _mon(8, 10)), isNull);
    });

    test('running beats one that starts soon', () {
      final slots = [
        _slot(1, 10, 1, '8:50', '9:35'),
        _slot(2, 20, 1, '8:00', '8:55'),
      ];
      expect(pickSubjectForNow(slots, _mon(8, 45)), 20);
    });

    test('of two upcoming slots the earlier start wins', () {
      final slots = [
        _slot(1, 10, 1, '8:08', '8:50'),
        _slot(2, 20, 1, '8:03', '8:50'),
      ];
      expect(pickSubjectForNow(slots, _mon(8, 0)), 20);
    });

    test('Sunday late evening sees a Monday slot just after midnight', () {
      final slots = [_slot(1, 10, 1, '0:03', '0:45')];
      expect(pickSubjectForNow(slots, DateTime(2026, 9, 13, 23, 55)), 10);
    });

    test('invalid slots are ignored', () {
      final slots = [_slot(1, 10, 9, '8:00', '8:45'), _slot(2, 20, 1, '9:00', '8:00')];
      expect(pickSubjectForNow(slots, _mon(8, 30)), isNull);
    });
  });

  test('formatting', () {
    expect(formatMinuteOfDay(485), '8:05');
    expect(formatSlot(_slot(1, 1, 3, '8:00', '8:45')), 'St 8:00–8:45');
  });

  group('todaySlotHint', () {
    test('a running slot is reported as running', () {
      final hint = todaySlotHint([_slot(1, 10, 1, '8:00', '8:45')], _mon(8, 10));
      expect(hint?.slot.id, 1);
      expect(hint?.running, isTrue);
    });

    test('otherwise the next slot today, earliest first', () {
      final slots = [
        _slot(1, 10, 1, '11:00', '11:45'),
        _slot(2, 11, 1, '9:00', '9:45'),
      ];
      final hint = todaySlotHint(slots, _mon(8, 50));
      expect(hint?.slot.id, 2);
      expect(hint?.running, isFalse);
    });

    test('other weekdays and finished slots give nothing', () {
      final slots = [
        _slot(1, 10, 2, '9:00', '9:45'),
        _slot(2, 11, 1, '7:00', '7:45'),
      ];
      expect(todaySlotHint(slots, _mon(8, 0)), isNull);
      expect(todaySlotHint(const [], _mon(8, 0)), isNull);
    });

    test('ties go to the lower id, the end minute is exclusive', () {
      final slots = [
        _slot(5, 10, 1, '8:00', '8:45'),
        _slot(3, 11, 1, '8:00', '8:45'),
      ];
      expect(todaySlotHint(slots, _mon(8, 0))?.slot.id, 3);
      expect(todaySlotHint(slots, _mon(8, 45)), isNull);
    });
  });

  group('slots in the database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('add, list, delete and validate', () async {
      final dao = db.subjectsDao;
      final cz = await db.savedNotesDao.createFolder('Čeština');
      final id = await dao.addSlot(
          subjectId: cz, weekday: 2, startMinute: 600, endMinute: 645);
      await dao.addSlot(subjectId: cz, weekday: 1, startMinute: 480, endMinute: 525);

      expect((await dao.allSlots()), hasLength(2));
      expect((await dao.watchSlots(cz).first).map((s) => s.weekday), [1, 2]);

      await dao.deleteSlot(id);
      expect(await dao.allSlots(), hasLength(1));

      expect(() => dao.addSlot(subjectId: cz, weekday: 0, startMinute: 1, endMinute: 2),
          throwsArgumentError);
      expect(() => dao.addSlot(subjectId: cz, weekday: 1, startMinute: 60, endMinute: 60),
          throwsArgumentError);
      expect(() => dao.addSlot(subjectId: cz, weekday: 1, startMinute: 60, endMinute: 1441),
          throwsArgumentError);
    });
  });
}
