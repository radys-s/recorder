import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/formatting.dart';

void main() {
  group('formatClock', () {
    test('pads to mm:ss under an hour', () {
      expect(formatClock(Duration.zero), '00:00');
      expect(formatClock(const Duration(seconds: 7)), '00:07');
      expect(formatClock(const Duration(minutes: 5, seconds: 3)), '05:03');
      expect(formatClock(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('grows to h:mm:ss past an hour', () {
      expect(formatClock(const Duration(hours: 1)), '1:00:00');
      expect(
        formatClock(const Duration(hours: 2, minutes: 7, seconds: 4)),
        '2:07:04',
      );
    });

    test('formatClockMs takes the millisecond offsets the DB stores', () {
      expect(formatClockMs(0), '00:00');
      expect(formatClockMs(63500), '01:03');
    });
  });

  group('formatDurationLabel', () {
    test('seconds only under a minute', () {
      expect(formatDurationLabel(const Duration(seconds: 42)), '42 s');
    });

    test('m:ss under an hour', () {
      expect(formatDurationLabel(const Duration(minutes: 5, seconds: 3)), '5:03');
    });

    test('hours and minutes above one hour', () {
      expect(
        formatDurationLabel(const Duration(hours: 2, minutes: 5, seconds: 30)),
        '2 h 05 min',
      );
    });
  });

  group('formatMeetingDate', () {
    // Fixed "now" so the test does not change meaning depending on the day it
    // runs — the whole point of the injectable parameter.
    final now = DateTime(2026, 9, 7, 14, 30);

    test('today and yesterday are named, not dated', () {
      expect(
        formatMeetingDate(DateTime(2026, 9, 7, 18, 16), now: now),
        'Dnes 18:16',
      );
      expect(
        formatMeetingDate(DateTime(2026, 9, 6, 9, 4), now: now),
        'Včera 9:04',
      );
    });

    test('an earlier day this year drops the year', () {
      expect(
        formatMeetingDate(DateTime(2026, 3, 12, 8, 5), now: now),
        '12. 3. 8:05',
      );
    });

    test('another year keeps it', () {
      expect(
        formatMeetingDate(DateTime(2025, 12, 31, 23, 59), now: now),
        '31. 12. 2025 23:59',
      );
    });

    test('a late-evening meeting is still "today", not rounded by the hour', () {
      expect(
        formatMeetingDate(DateTime(2026, 9, 7, 0, 1), now: now),
        'Dnes 0:01',
      );
    });
  });

  group('formatDateGroup', () {
    final now = DateTime(2026, 9, 7, 14, 30);

    test('groups by day, with the two relative names', () {
      expect(formatDateGroup(DateTime(2026, 9, 7, 2, 0), now: now), 'Dnes');
      expect(formatDateGroup(DateTime(2026, 9, 6, 23, 0), now: now), 'Včera');
      expect(formatDateGroup(DateTime(2026, 9, 5, 12, 0), now: now), '5. 9.');
      expect(
        formatDateGroup(DateTime(2025, 9, 5, 12, 0), now: now),
        '5. 9. 2025',
      );
    });
  });
}
