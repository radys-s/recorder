import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/lesson_end_watcher.dart';

void main() {
  late List<String> events;
  late LessonEndWatcher watcher;
  late DateTime clock;

  setUp(() {
    events = [];
    clock = DateTime(2026, 9, 14, 8, 0);
  });

  LessonEndWatcher build() => LessonEndWatcher(
    scheduleNotification: (end, id) async => events.add('schedule $id $end'),
    cancelNotification: () async => events.add('cancel'),
    onOver: (over) => events.add('over $over'),
    now: () => clock,
  );

  test('says so at the end of the slot and schedules the notification', () {
    fakeAsync((async) {
      watcher = build();
      watcher.start(end: DateTime(2026, 9, 14, 8, 45), meetingId: 7);
      expect(events, ['over false', 'schedule 7 2026-09-14 08:45:00.000']);

      async.elapse(const Duration(minutes: 44));
      expect(events.contains('over true'), isFalse);
      async.elapse(const Duration(minutes: 1));
      expect(events.last, 'over true');
      expect(watcher.armed, isFalse);
    });
  });

  test('stopping early clears the hint and the pending notification', () {
    fakeAsync((async) {
      watcher = build();
      watcher.start(end: DateTime(2026, 9, 14, 8, 45), meetingId: 7);
      events.clear();

      watcher.stop();
      expect(events, ['over false', 'cancel']);
      async.elapse(const Duration(hours: 2));
      expect(events.contains('over true'), isFalse);
    });
  });

  test('a lesson recorded after its slot announces nothing', () {
    fakeAsync((async) {
      clock = DateTime(2026, 9, 14, 9, 0);
      watcher = build();
      watcher.start(end: DateTime(2026, 9, 14, 8, 45), meetingId: 7);
      async.elapse(const Duration(hours: 1));
      expect(events, ['over false']);
      expect(watcher.armed, isFalse);
    });
  });

  test('a new recording replaces the previous watch', () {
    fakeAsync((async) {
      watcher = build();
      watcher.start(end: DateTime(2026, 9, 14, 8, 45), meetingId: 7);
      watcher.start(end: DateTime(2026, 9, 14, 9, 30), meetingId: 8);
      async.elapse(const Duration(minutes: 50));
      expect(events.contains('over true'), isFalse);
      async.elapse(const Duration(minutes: 40));
      expect(events.last, 'over true');
    });
  });
}
