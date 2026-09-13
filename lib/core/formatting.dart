import 'package:intl/intl.dart';

/// Duration and date formatting, in one place.
///
/// There used to be three private formatters in three widgets producing three
/// different shapes for the same number — `5:03` in the list, `05:03` in the
/// banner, `00:05:03`-ish in the transcript. A duration that changes shape
/// depending on where it is shown reads as a different quantity.

/// Elapsed time as a clock: `mm:ss`, growing to `h:mm:ss` past an hour.
///
/// Used wherever a running or positional time is shown — the recording banner
/// and the transcript timestamps. Pair it with `FontFeature.tabularFigures()`
/// so the digits do not jitter as they change.
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// The same clock from a millisecond offset, which is how the database stores
/// segment boundaries.
String formatClockMs(int ms) => formatClock(Duration(milliseconds: ms));

/// A duration as a human label rather than a clock: `2 h 05 min`, `5:03`,
/// `42 s`. For summaries, where "how long was this" matters and the exact
/// second does not.
String formatDurationLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
  if (m > 0) return '$m:${s.toString().padLeft(2, '0')}';
  return '$s s';
}

final _timeOfDay = DateFormat('H:mm');
final _fullDate = DateFormat('d. M. y');
final _dateInYear = DateFormat('d. M.');

/// Just the time of day: `9:50`. Used in the meetings list, where the day is
/// already stated by the group heading above the row and repeating it would be
/// noise.
String formatTimeOfDay(DateTime when) => _timeOfDay.format(when);

/// When a meeting happened, relative for the two days people actually think
/// in: `Dnes 18:16`, `Včera 9:04`, `4. 9. 18:16`, `4. 9. 2025 18:16`.
///
/// [now] is injectable so the tests do not depend on the day they run.
String formatMeetingDate(DateTime when, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final day = _dayOf(when);
  final time = _timeOfDay.format(when);

  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Dnes $time';
  if (diff == 1) return 'Včera $time';

  // The year is noise for anything from this year and essential for anything
  // older, so it appears only when it disambiguates.
  final date =
      when.year == today.year ? _dateInYear.format(when) : _fullDate.format(when);
  return '$date $time';
}

/// The date group a meeting belongs to in the list: `Dnes`, `Včera`, then the
/// date on its own.
String formatDateGroup(DateTime when, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final day = _dayOf(when);

  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Dnes';
  if (diff == 1) return 'Včera';
  return when.year == today.year
      ? _dateInYear.format(when)
      : _fullDate.format(when);
}

/// Midnight of the day [t] falls on, so two timestamps can be compared by day
/// without the hours getting in the way.
DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
