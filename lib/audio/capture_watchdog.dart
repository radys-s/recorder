/// What the recording controller should do about the microphone right now.
enum WatchdogVerdict { healthy, restart, giveUp }

/// Notices a microphone that stopped delivering audio without saying so.
///
/// On iOS a route change, a call or Siri can stop the capture with neither an
/// error nor a closed stream, so the lesson keeps "recording" silence. The
/// controller feeds this every stream event and asks [check] once a second.
///
/// Pure: the clock is passed in, so every rule is testable without waiting.
class CaptureWatchdog {
  CaptureWatchdog({
    this.stallAfter = const Duration(seconds: 3),
    this.maxRestarts = 3,
    this.stableAfter = const Duration(seconds: 10),
  });

  /// No bytes for this long counts as a stall.
  final Duration stallAfter;

  /// Restarts allowed in a row before the recording is given up.
  final int maxRestarts;

  /// Audio has to flow this long after a restart before the count is forgiven,
  /// so a mic that flaps every few seconds still ends up given up on.
  final Duration stableAfter;

  DateTime? _lastData;
  DateTime? _flowingSince;
  int _restarts = 0;

  int get restarts => _restarts;

  void start(DateTime now) {
    _lastData = now;
    _flowingSince = null;
    _restarts = 0;
  }

  void onData(DateTime now) {
    _lastData = now;
    final since = _flowingSince ??= now;
    if (now.difference(since) >= stableAfter) _restarts = 0;
  }

  /// [paused] slides the deadline forward, so resuming does not look like a
  /// stall that has lasted the whole pause.
  WatchdogVerdict check(DateTime now, {required bool paused}) {
    if (paused) {
      _lastData = now;
      _flowingSince = null;
      return WatchdogVerdict.healthy;
    }
    final last = _lastData ??= now;
    if (now.difference(last) < stallAfter) return WatchdogVerdict.healthy;
    if (_restarts >= maxRestarts) return WatchdogVerdict.giveUp;
    _restarts++;
    // Grace period: the restart itself takes a moment to produce audio.
    _lastData = now;
    _flowingSince = null;
    return WatchdogVerdict.restart;
  }
}

/// Tells "the microphone is on but hears nothing at all" apart from a quiet
/// room: a working mic always has some noise floor, a muted or dead one gives
/// exact silence.
class SilentMicDetector {
  SilentMicDetector({
    this.threshold = 0.0002,
    this.after = const Duration(seconds: 10),
    this.frameDuration = const Duration(milliseconds: 100),
  });

  /// Normalised RMS below which a frame counts as dead silence (about -74 dBFS).
  final double threshold;
  final Duration after;
  final Duration frameDuration;

  int _silentMs = 0;
  bool _silent = false;

  bool get silent => _silent;

  /// Returns true when [silent] changed.
  bool add(double rms) {
    if (rms < threshold) {
      _silentMs += frameDuration.inMilliseconds;
      if (!_silent && _silentMs >= after.inMilliseconds) {
        _silent = true;
        return true;
      }
      return false;
    }
    _silentMs = 0;
    if (_silent) {
      _silent = false;
      return true;
    }
    return false;
  }
}
