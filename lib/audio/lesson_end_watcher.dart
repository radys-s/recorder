import 'dart:async';

/// Tells the student that the timetable says their lesson is over while the
/// recording is still running — a phone left on the desk after the bell is the
/// usual way a lesson recording runs for hours.
///
/// It never stops anything: the teacher may overrun, and an ended recording
/// cannot be resumed. It only says so, once, twice at most: a system
/// notification for when the phone is in a pocket and [onOver] for the screen.
class LessonEndWatcher {
  LessonEndWatcher({
    required this.scheduleNotification,
    required this.cancelNotification,
    required this.onOver,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Hands the system notification for [end] over; [meetingId] is what a tap
  /// should open.
  final Future<void> Function(DateTime end, int meetingId) scheduleNotification;
  final Future<void> Function() cancelNotification;

  /// Called with true at the end of the lesson, with false when it is
  /// cleared (recording stopped or a new one began).
  final void Function(bool over) onOver;
  final DateTime Function() _now;

  Timer? _timer;

  /// Arms the watcher for [end]. An [end] that has already passed does
  /// nothing: a lesson recorded after its slot has nothing to announce.
  void start({required DateTime end, required int meetingId}) {
    stop();
    final wait = end.difference(_now());
    if (wait <= Duration.zero) return;
    _timer = Timer(wait, () {
      _timer = null;
      onOver(true);
    });
    scheduleNotification(end, meetingId);
  }

  /// Disarms everything, including a notification not yet shown.
  void stop() {
    final armed = _timer != null;
    _timer?.cancel();
    _timer = null;
    onOver(false);
    if (armed) cancelNotification();
  }

  bool get armed => _timer != null;
}
