import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/logging.dart';

/// Entry point for the foreground service's isolate.
///
/// Must be a top-level function marked as a VM entry point, because the plugin
/// looks it up by symbol when it spawns the isolate.
@pragma('vm:entry-point')
void startRecordingTaskHandler() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

/// A deliberately near-empty task handler.
///
/// The recording pipeline (mic stream, chunker, drift writes) lives in the
/// **main** isolate — see `foreground_recording_service.dart` for why. This
/// handler exists only because the plugin requires one; the foreground service
/// it belongs to is what actually matters, since that is what stops Android
/// from killing the process while the app is backgrounded.
///
/// Keep it free of real work: it runs in a separate isolate with no shared
/// memory, so anything here cannot see the recording state anyway.
class RecordingTaskHandler extends TaskHandler {
  static const _tag = 'audio.fgs.task';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    AppLog.d(_tag, 'task handler started (starter=${starter.name})');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat only — proves the service is alive in logcat.
    AppLog.d(_tag, 'heartbeat $timestamp');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    AppLog.d(_tag, 'task handler destroyed (isTimeout=$isTimeout)');
  }
}
