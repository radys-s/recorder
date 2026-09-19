import '../core/lesson_reminders.dart';
import '../core/logging.dart';
import 'db/app_database.dart';
import 'db/tables/preferences_table.dart';

/// Keeps the phone's pending notifications in step with the timetable.
///
/// Everything is re-planned from scratch: the existing notifications are
/// cancelled and the next two weeks scheduled again. A timetable is a dozen
/// rows, so the cheap thing and the correct thing are the same thing here —
/// no bookkeeping about which reminder belonged to which deleted slot.
class LessonReminderService {
  LessonReminderService(this._db, this._scheduler, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _tag = 'reminders';

  final AppDatabase _db;
  final ReminderScheduler _scheduler;
  final DateTime Function() _now;

  /// The run in progress. Startup, a timetable edit and the switch in
  /// Nastavení can all ask at once, and two runs interleaving their cancel and
  /// schedule steps would leave every reminder planned twice.
  Future<void> _running = Future.value();

  /// Returns how many reminders are now pending.
  Future<int> reschedule() {
    final run = _running.then((_) => _reschedule());
    _running = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<int> _reschedule() async {
    final prefs = await _db.preferencesDao.current();
    final lead = prefs.lessonReminder.lead;

    await _scheduler.cancelAll();
    if (lead == null) return 0;

    final subjects = {
      for (final s in await _db.subjectsDao.allSubjects())
        s.subject.id: s.subject.name,
    };
    final slots = <ReminderSlot>[];
    for (final slot in await _db.subjectsDao.allSlots()) {
      final name = subjects[slot.subjectId];
      // A slot whose subject is gone is a leftover, not a lesson.
      if (name == null) continue;
      slots.add(
        ReminderSlot(
          subjectId: slot.subjectId,
          subjectName: name,
          weekday: slot.weekday,
          startMinute: slot.startMinute,
        ),
      );
    }

    final planned = planReminders(slots: slots, lead: lead, from: _now());
    for (final reminder in planned) {
      await _scheduler.schedule(reminder);
    }
    AppLog.d(_tag, 'scheduled ${planned.length} lesson reminder(s)');
    return planned.length;
  }

  /// Turning the reminder on asks for permission at the moment the user can
  /// tell what it is for. A refusal leaves the setting off rather than
  /// pretending to be on with nothing behind it.
  Future<bool> setReminder(LessonReminder value) async {
    if (value != LessonReminder.off && !await _scheduler.ensurePermission()) {
      await _db.preferencesDao.setLessonReminder(LessonReminder.off);
      await reschedule();
      return false;
    }
    await _db.preferencesDao.setLessonReminder(value);
    await reschedule();
    return true;
  }
}
