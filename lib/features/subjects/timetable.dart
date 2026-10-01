import '../../data/db/app_database.dart';

/// How far ahead a lesson counts as "about to start" for the start sheet.
const Duration kTimetableLookahead = Duration(minutes: 10);

/// Czech short weekday names, `DateTime.weekday` order (1 = Monday).
const List<String> kWeekdayShort = ['Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne'];

/// Czech weekday names, `DateTime.weekday` order (1 = Monday).
const List<String> kWeekdayLong = [
  'Pondělí',
  'Úterý',
  'Středa',
  'Čtvrtek',
  'Pátek',
  'Sobota',
  'Neděle',
];

/// `8:05`.
String formatMinuteOfDay(int minute) =>
    '${minute ~/ 60}:${(minute % 60).toString().padLeft(2, '0')}';

/// `Po 8:00–8:45`.
String formatSlot(TimetableSlot slot) =>
    '${kWeekdayShort[slot.weekday - 1]} '
    '${formatMinuteOfDay(slot.startMinute)}–${formatMinuteOfDay(slot.endMinute)}';

/// The subject the timetable says is on at [now]: a slot running now, else one
/// starting within [kTimetableLookahead]. Ties go to the earlier start, then
/// to the lower slot id, so the answer never depends on row order.
///
/// Minutes are counted across the whole week, so a lesson at 0:05 on Monday is
/// "within ten minutes" of Sunday 23:58.
int? pickSubjectForNow(List<TimetableSlot> slots, DateTime now) {
  const week = 7 * 24 * 60;
  final nowMinute = (now.weekday - 1) * 24 * 60 + now.hour * 60 + now.minute;

  TimetableSlot? best;
  int? bestStart;
  for (final slot in slots) {
    if (slot.weekday < 1 || slot.weekday > 7) continue;
    if (slot.endMinute <= slot.startMinute) continue;
    final start = (slot.weekday - 1) * 24 * 60 + slot.startMinute;
    final end = start + slot.endMinute - slot.startMinute;

    // Distance from now to the start, going forward around the week.
    final ahead = (start - nowMinute) % week;
    final running = nowMinute >= start && nowMinute < end;
    final soon = ahead > 0 && ahead <= kTimetableLookahead.inMinutes;
    if (!running && !soon) continue;

    // Running slots started in the past; give them a start before now.
    final effective = running ? start - nowMinute : ahead;
    if (best == null ||
        effective < bestStart! ||
        (effective == bestStart && slot.id < best.id)) {
      best = slot;
      bestStart = effective;
    }
  }
  return best?.subjectId;
}

/// Longest gap between two slots of one subject that still counts as one
/// lesson — the long break of a double lesson, as in the timetable import.
const Duration kLessonChainGap = Duration(minutes: 20);

/// When the lesson of [subjectId] that [startedAt] belongs to ends, by the
/// timetable: a slot of that subject running at [startedAt] or starting within
/// [kTimetableLookahead] of it, extended through following slots of the same
/// subject that start within [kLessonChainGap] of the previous end (a double
/// lesson is two slots). Null when the timetable has no such lesson that day.
DateTime? lessonEndFor(
  List<TimetableSlot> slots,
  int subjectId,
  DateTime startedAt,
) {
  final minute = startedAt.hour * 60 + startedAt.minute;
  final today = [
    for (final s in slots)
      if (s.subjectId == subjectId &&
          s.weekday == startedAt.weekday &&
          s.endMinute > s.startMinute)
        s,
  ]..sort((a, b) => a.startMinute.compareTo(b.startMinute));

  TimetableSlot? first;
  for (final s in today) {
    final running = s.startMinute <= minute && minute < s.endMinute;
    final soon =
        s.startMinute > minute &&
        s.startMinute - minute <= kTimetableLookahead.inMinutes;
    if (running || soon) {
      first = s;
      break;
    }
  }
  if (first == null) return null;

  var end = first.endMinute;
  for (final s in today) {
    if (s.startMinute < first.startMinute || identical(s, first)) continue;
    if (s.startMinute <= end + kLessonChainGap.inMinutes && s.endMinute > end) {
      end = s.endMinute;
    }
  }
  return DateTime(
    startedAt.year,
    startedAt.month,
    startedAt.day,
    end ~/ 60,
    end % 60,
  );
}

/// What the home screen says about today: the lesson running now, else the
/// next one still to come today. Ties go to the earlier start, then the lower
/// id. Unlike [pickSubjectForNow] this never looks past midnight — "next" on a
/// Friday evening is not Monday's first lesson.
({TimetableSlot slot, bool running})? todaySlotHint(
  List<TimetableSlot> slots,
  DateTime now,
) {
  final minute = now.hour * 60 + now.minute;
  bool before(TimetableSlot a, TimetableSlot? b) =>
      b == null ||
      a.startMinute < b.startMinute ||
      (a.startMinute == b.startMinute && a.id < b.id);

  TimetableSlot? running;
  TimetableSlot? next;
  for (final slot in slots) {
    if (slot.weekday != now.weekday) continue;
    if (slot.endMinute <= slot.startMinute) continue;
    if (slot.startMinute <= minute && minute < slot.endMinute) {
      if (before(slot, running)) running = slot;
    } else if (slot.startMinute > minute) {
      if (before(slot, next)) next = slot;
    }
  }
  if (running != null) return (slot: running, running: true);
  if (next != null) return (slot: next, running: false);
  return null;
}
