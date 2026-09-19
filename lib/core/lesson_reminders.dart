/// Turning a timetable into the notifications that remind the student a
/// lesson is about to start.
///
/// Pure on purpose: the whole decision — which lessons, at what moment, how
/// many — is testable without a notification plugin, a device or a clock.
library;

/// One timetabled lesson, reduced to what a reminder needs.
class ReminderSlot {
  const ReminderSlot({
    required this.subjectId,
    required this.subjectName,
    required this.weekday,
    required this.startMinute,
  });

  final int subjectId;
  final String subjectName;

  /// 1 = Monday … 7 = Sunday, the same numbering `DateTime.weekday` uses.
  final int weekday;

  /// Minutes since midnight.
  final int startMinute;
}

/// One notification to hand to the system.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.subjectId,
    required this.title,
    required this.body,
  });

  /// Stable for a given day and time, so re-planning the same week produces
  /// the same ids rather than a second set beside the first.
  final int id;

  /// Local wall-clock time the notification fires at.
  final DateTime at;

  final int subjectId;
  final String title;
  final String body;
}

/// How far ahead reminders are scheduled.
///
/// The app re-plans at every start and whenever the timetable changes, so the
/// horizon only has to outlast the gaps between two launches — and a short
/// one keeps the list inside iOS's limit without needing weekly repetition,
/// which cannot be expressed correctly without the device's own time zone.
const kReminderHorizon = Duration(days: 14);

/// iOS keeps at most 64 pending notifications and silently drops the rest, so
/// the plan stops below that.
const kReminderCap = 60;

/// The lessons of the next [horizon] that start after [from], soonest first.
///
/// [lead] is how long before the lesson the notification fires;
/// `Duration.zero` means at the start.
List<PlannedReminder> planReminders({
  required List<ReminderSlot> slots,
  required Duration lead,
  required DateTime from,
  Duration horizon = kReminderHorizon,
  int cap = kReminderCap,
}) {
  if (slots.isEmpty || cap <= 0) return const [];

  final start = DateTime(from.year, from.month, from.day);
  final days = horizon.inDays;
  final byMoment = <DateTime, PlannedReminder>{};

  for (var offset = 0; offset <= days; offset++) {
    final day = DateTime(start.year, start.month, start.day + offset);
    for (final slot in slots) {
      if (slot.weekday != day.weekday) continue;
      // Built from the hour and minute rather than by adding a Duration to
      // midnight, so a lesson keeps its wall-clock time across a DST change.
      final lesson = DateTime(
        day.year,
        day.month,
        day.day,
        slot.startMinute ~/ 60,
        slot.startMinute % 60,
      );
      final at = lesson.subtract(lead);
      if (!at.isAfter(from)) continue;
      // Two subjects at the same minute is a broken timetable, not a reason
      // for two notifications; the first one wins.
      byMoment.putIfAbsent(
        at,
        () => PlannedReminder(
          id: offset * 10000 + at.hour * 60 + at.minute,
          at: at,
          subjectId: slot.subjectId,
          title: lead == Duration.zero
              ? 'Začíná ${slot.subjectName}'
              : 'Za chvíli začíná ${slot.subjectName}',
          body: 'Nahrát hodinu?',
        ),
      );
    }
  }

  final planned = byMoment.values.toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return planned.length <= cap ? planned : planned.sublist(0, cap);
}

/// What the app needs from the notification system.
///
/// An interface, so scheduling is testable and so nothing outside the one
/// implementation has to know the plugin exists.
abstract class ReminderScheduler {
  /// Asks the system for permission to show notifications. False means the
  /// user said no — the setting then has nothing to do.
  Future<bool> ensurePermission();

  Future<void> cancelAll();

  Future<void> schedule(PlannedReminder reminder);
}
