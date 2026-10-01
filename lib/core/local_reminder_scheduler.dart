import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'lesson_reminders.dart';
import 'logging.dart';

/// [ReminderScheduler] over the system's own notifications.
///
/// Two decisions worth knowing:
///
/// **Absolute instants, not weekly repetition.** The plugin's weekly mode
/// matches a weekday and time inside a named time zone, and naming the
/// device's zone needs a package that reads it — which this app does not
/// have. Converting each lesson's wall-clock time to a UTC instant is exact
/// (the OS resolves the offset, DST included), so the reminders are simply
/// re-planned for the next two weeks at every launch and whenever the
/// timetable changes.
///
/// **Inexact alarms on Android.** Exact ones need `SCHEDULE_EXACT_ALARM`,
/// which is a permission dialog and a Play policy for something that says „za
/// chvíli začíná" — a minute either way changes nothing.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.onTap,
    this.onOpenLesson,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _tag = 'reminders';
  static const _channelId = 'lesson_reminders';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Připomínky hodin',
      channelDescription: 'Upozorní, že za chvíli začíná hodina z rozvrhu.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin;

  /// Called with the subject of the reminder the user tapped.
  final void Function(int subjectId)? onTap;

  /// Called with the lesson of a „výpisky jsou hotové" notification the user
  /// tapped.
  final void Function(int meetingId)? onOpenLesson;

  /// The „hodina skončila" notification of the lesson being recorded. Not in
  /// the range the timetable reminders use, and kept out of [cancelAll] so that
  /// re-planning the week mid-lesson does not drop it.
  static const int lessonEndId = 4302;

  /// Payload of a notification that opens a lesson.
  static String lessonPayload(int meetingId) => 'lesson:$meetingId';

  bool _ready = false;

  /// Safe to call more than once; the second call does nothing.
  ///
  /// Returns the subject of a reminder the app was launched by, if any — on a
  /// cold start the tap arrives as launch details rather than as a callback.
  Future<int?> init() async {
    if (kIsWeb || _ready) return null;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Asked for later, by the switch in Nastavení, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _handlePayload(response.payload),
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final payload = launch?.notificationResponse?.payload;
        final lessonId = lessonOf(payload);
        if (lessonId != null) {
          onOpenLesson?.call(lessonId);
          return null;
        }
        return _subjectOf(payload);
      }
    } catch (e, st) {
      AppLog.e(_tag, 'notifications could not be initialised', e, st);
    }
    return null;
  }

  @override
  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    await init();
    if (!_ready) return false;
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      // A desktop or test host has no permission to ask for.
      return true;
    } catch (e, st) {
      AppLog.e(_tag, 'permission request failed', e, st);
      return false;
    }
  }

  @override
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.id == lessonEndId) continue;
        await _plugin.cancel(id: request.id);
      }
    } catch (e, st) {
      AppLog.e(_tag, 'cancelling reminders failed', e, st);
    }
  }

  /// One notification at [at] that opens [meetingId] when tapped.
  Future<void> scheduleLessonEnd({
    required DateTime at,
    required int meetingId,
    required String subjectName,
  }) async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: lessonEndId,
        title: 'Hodina $subjectName skončila',
        body: 'Nahrávání pořád běží — ukončit?',
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: lessonPayload(meetingId),
      );
    } catch (e, st) {
      AppLog.e(_tag, 'scheduling the lesson-end notice failed', e, st);
    }
  }

  Future<void> cancelLessonEnd() async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: lessonEndId);
    } catch (e, st) {
      AppLog.e(_tag, 'cancelling the lesson-end notice failed', e, st);
    }
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        // `from` converts the instant, so the UTC location here is a way of
        // naming the moment, not a way of shifting it.
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '${reminder.subjectId}',
      );
    } catch (e, st) {
      AppLog.e(_tag, 'scheduling a reminder failed', e, st);
    }
  }

  /// A notification right now, for something the student must not miss while
  /// the phone is in a pocket — a recording that stopped. Shows only if the
  /// permission was already given (by the reminder switch); it never asks.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: payload,
      );
    } catch (e, st) {
      AppLog.e(_tag, 'showing a notification failed', e, st);
    }
  }

  void _handlePayload(String? payload) {
    final lessonId = lessonOf(payload);
    if (lessonId != null) {
      onOpenLesson?.call(lessonId);
      return;
    }
    final subjectId = _subjectOf(payload);
    if (subjectId != null) onTap?.call(subjectId);
  }

  /// The lesson a payload names, if it is a lesson payload.
  static int? lessonOf(String? payload) =>
      payload != null && payload.startsWith('lesson:')
      ? int.tryParse(payload.substring('lesson:'.length))
      : null;

  static int? _subjectOf(String? payload) =>
      payload == null ? null : int.tryParse(payload);
}
