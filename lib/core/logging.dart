import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'redaction.dart';

/// Thin logging wrapper so milestone verification (e.g. "watch adb logcat
/// for continuous byte-count lines") has one consistent, greppable tag.
///
/// Uses [debugPrint] rather than `dart:developer`'s `log`, because only stdout
/// is forwarded to Android's logcat — `log` goes to the VM service instead and
/// would be invisible to `adb logcat`. [debugPrint] also throttles output, so
/// high-frequency logging (the PCM stream) doesn't drop lines.
///
/// Three rules keep a release build's log safe to hand to somebody else:
/// - [d] is debug-only: it may carry detail (raw response bodies, ids) that is
///   fine on a developer's machine and not in a report.
/// - [i], [w] and [e] never receive question or transcript text — callers pass
///   counts, ids and kinds.
/// - Every line, whatever the level, is passed through [redactSecrets] and kept
///   in a 500-line ring buffer that "Nahlásit problém" reads.
class AppLog {
  const AppLog._();

  /// How many lines the report can include.
  static const int capacity = 500;

  static final Queue<String> _lines = Queue<String>();

  /// Set by tests to see what would have been logged in a release build.
  @visibleForTesting
  static bool? debugOverride;

  static bool get _debug => debugOverride ?? kDebugMode;

  /// Detail for the developer; dropped entirely in a release build.
  static void d(String tag, String message) {
    if (!_debug) return;
    _emit('D', tag, message);
  }

  /// A normal event worth keeping in a report.
  static void i(String tag, String message) => _emit('I', tag, message);

  static void w(String tag, String message) => _emit('W', tag, message);

  static void e(String tag, String message, [Object? error, StackTrace? st]) {
    // Only the error's type and a redacted excerpt: its `toString()` can carry
    // a request with its headers.
    final detail = error == null ? '' : ' | ${describeError(error)}';
    _emit('E', tag, '$message$detail');
    if (st != null && _debug) debugPrint(st.toString());
  }

  /// The buffered lines, oldest first.
  static List<String> get recent => List.unmodifiable(_lines);

  @visibleForTesting
  static void clear() => _lines.clear();

  static void _emit(String level, String tag, String message) {
    final line = redactSecrets('$level [$tag] $message');
    _lines.addLast(line);
    while (_lines.length > capacity) {
      _lines.removeFirst();
    }
    debugPrint('[recorder.$tag] ${level == 'E' ? 'ERROR: ' : ''}'
        '${line.substring(line.indexOf(']') + 2)}');
  }
}
