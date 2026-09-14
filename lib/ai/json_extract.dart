import 'dart:convert';

/// The single JSON object in a model's reply, or null if there is not one.
///
/// Groq's `response_format: json_object` makes a clean object very likely and
/// never certain, and the agentic models cannot be asked for it at all — they
/// narrate what they searched for and then hand over the object. So every
/// caller parses defensively: try the whole string, then the outermost
/// `{...}` object embedded in it, then give up. Giving up always means "no
/// result", never an exception thrown at a caller that is holding a live
/// meeting open.
///
/// An embedded object is found by matching its own braces, not by taking the
/// first `{` to the last `}`: prose that mentions a brace before or after the
/// object ("…pak {"is_question": true} (viz {x})") used to make the whole span
/// undecodable, and a real question came back as no question at all.
Map<Object?, Object?>? extractJsonObject(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<Object?, Object?>() : null;
  } catch (_) {
    // Not JSON as a whole; look for an object inside the prose.
  }

  Map<Object?, Object?>? empty;
  for (var start = raw.indexOf('{');
      start >= 0;
      start = raw.indexOf('{', start + 1)) {
    final end = _closingBrace(raw, start);
    if (end < 0) continue;
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      if (decoded is! Map) continue;
      // A bare "{}" in the narration is not the answer if a real one follows.
      if (decoded.isNotEmpty) return decoded.cast<Object?, Object?>();
      empty ??= decoded.cast<Object?, Object?>();
    } catch (_) {
      // A brace in prose, not an object. Try the next one.
    }
  }
  return empty;
}

/// Index of the `}` that closes the object opening at [start], or -1.
/// Braces inside string literals do not count, escapes included.
int _closingBrace(String s, int start) {
  var depth = 0;
  var inString = false;
  for (var i = start; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (inString) {
      if (c == 0x5C) {
        i++; // backslash: the next character is escaped
      } else if (c == 0x22) {
        inString = false;
      }
    } else if (c == 0x22) {
      inString = true;
    } else if (c == 0x7B) {
      depth++;
    } else if (c == 0x7D && --depth == 0) {
      return i;
    }
  }
  return -1;
}
