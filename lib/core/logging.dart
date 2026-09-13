import 'package:flutter/foundation.dart';

/// Thin logging wrapper so milestone verification (e.g. "watch adb logcat
/// for continuous byte-count lines") has one consistent, greppable tag.
///
/// Uses [debugPrint] rather than `dart:developer`'s `log`, because only stdout
/// is forwarded to Android's logcat — `log` goes to the VM service instead and
/// would be invisible to `adb logcat`. [debugPrint] also throttles output, so
/// high-frequency logging (the PCM stream) doesn't drop lines.
class AppLog {
  const AppLog._();

  static void d(String tag, String message) {
    debugPrint('[recorder.$tag] $message');
  }

  static void e(String tag, String message, [Object? error, StackTrace? st]) {
    debugPrint('[recorder.$tag] ERROR: $message${error == null ? '' : ' | $error'}');
    if (st != null) debugPrint(st.toString());
  }
}
