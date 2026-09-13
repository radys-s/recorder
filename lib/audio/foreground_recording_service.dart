import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/logging.dart';
import 'recording_task_handler.dart';

/// Keeps the app's process alive while recording, and owns the persistent
/// "recording" notification.
///
/// Architectural note: `flutter_foreground_task` runs its [TaskHandler] in a
/// separate isolate with no shared memory. Rather than move the mic stream and
/// the database into that isolate — which would need background-isolate support
/// from `record` and a second drift connection — everything stays in the main
/// isolate and this service is used purely as a keepalive. Starting *any*
/// foreground service protects the whole process, main isolate included.
///
/// **Android only.** iOS has no equivalent to a foreground service, and it does
/// not need one: what keeps a backgrounded recording alive there is
/// `UIBackgroundModes: [audio]` in `Info.plist` together with the active
/// `.playAndRecord` `AVAudioSession` that `record_ios` establishes on its own.
/// The persistent notification's job — telling the user the mic is live — is
/// done by the system's own orange indicator in the status bar, which is
/// harder to miss than a notification.
///
/// The guards live inside each method rather than at the call sites, so
/// `RecordingController` and `main.dart` read the same on both platforms. The
/// return values are chosen so that nothing downstream mistakes "not
/// applicable here" for "failed": [start] and [ensureNotificationPermission]
/// answer true, and the controller's "capture is unprotected" warning
/// correctly never fires on iOS.
///
/// Note that gating in Dart does **not** stop the plugin's own iOS launch
/// work — `SwiftFlutterForegroundTaskPlugin` registers a `BGTaskScheduler`
/// identifier from `didFinishLaunchingWithOptions` whether Dart touches it or
/// not, and raises if that identifier is missing from
/// `BGTaskSchedulerPermittedIdentifiers`. That plist key is mandatory
/// regardless of anything in this file.
class ForegroundRecordingService {
  const ForegroundRecordingService();

  static const _tag = 'audio.fgs';
  static const _serviceId = 4001;

  /// Whether this platform has the thing at all.
  static bool get _supported => Platform.isAndroid;

  /// Registers the notification channel and task options. Safe to call more
  /// than once; must be called before [start].
  void configure() {
    if (!_supported) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'recorder_recording',
        channelName: 'Recording',
        channelDescription: 'Shown while a meeting is being recorded.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // A recording notification should be unobtrusive but permanent.
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The handler does no real work, so a slow heartbeat is plenty.
        eventAction: ForegroundTaskEventAction.repeat(30000),
        allowWakeLock: true,
        allowWifiLock: true,
        autoRunOnBoot: false,
      ),
    );
  }

  /// Asks for notification permission. A denial is not fatal: on Android 13+
  /// the service still runs, the notification is just not shown, and the
  /// in-app recording banner still satisfies the "always visible" requirement.
  Future<bool> ensureNotificationPermission() async {
    if (!_supported) return true;

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission == NotificationPermission.granted) return true;

    final result = await FlutterForegroundTask.requestNotificationPermission();
    final granted = result == NotificationPermission.granted;
    if (!granted) {
      AppLog.d(_tag, 'notification permission not granted ($result)');
    }
    return granted;
  }

  Future<bool> get isRunning async =>
      _supported && await FlutterForegroundTask.isRunningService;

  /// Starts the service. [title]/[text] populate the persistent notification.
  Future<bool> start({required String title, required String text}) async {
    if (!_supported) return true;

    if (await isRunning) {
      AppLog.d(_tag, 'service already running');
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      // Android 14+ demands a declared type; microphone is what we actually do.
      serviceTypes: const [ForegroundServiceTypes.microphone],
      notificationTitle: title,
      notificationText: text,
      callback: startRecordingTaskHandler,
    );

    if (result is ServiceRequestSuccess) {
      AppLog.d(_tag, 'service started');
      return true;
    }

    AppLog.e(_tag, 'failed to start service', result);
    return false;
  }

  /// Updates the persistent notification's text without restarting anything.
  Future<void> updateNotification({required String title, required String text}) async {
    if (!await isRunning) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  Future<void> stop() async {
    if (!_supported) return;
    if (!await isRunning) return;

    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestSuccess) {
      AppLog.d(_tag, 'service stopped');
    } else {
      AppLog.e(_tag, 'failed to stop service', result);
    }
  }
}
