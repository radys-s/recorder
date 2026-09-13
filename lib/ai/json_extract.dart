import 'dart:convert';

/// The single JSON object in a model's reply, or null if there is not one.
///
/// Groq's `response_format: json_object` makes a clean object very likely and
/// never certain, and the agentic models cannot be asked for it at all — they
/// narrate what they searched for and then hand over the object. So every
/// caller parses defensively: try the whole string, then the outermost
/// `{...}` inside it, then give up. Giving up always means "no result",
/// never an exception thrown at a caller that is holding a live meeting open.
Map<Object?, Object?>? extractJsonObject(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      decoded = jsonDecode(raw.substring(start, end + 1));
    } catch (_) {
      return null;
    }
  }
  return decoded is Map ? decoded.cast<Object?, Object?>() : null;
}
