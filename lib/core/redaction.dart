/// Masks anything in [text] that looks like a credential.
///
/// A stored or shown error is the one place a key can escape the Keychain: a
/// `FormatException` from an invalid header value, a `DioException` with its
/// request options, a server that echoes the `Authorization` header back. This
/// is the last line of defence, run on every error that is persisted (queue
/// rows, notes, export, the diagnostic report) or put in front of the user.
///
/// It is deliberately greedy: a false positive costs a few characters of a log
/// line, a false negative costs a key.
String redactSecrets(String text) {
  var out = text;
  for (final pattern in _patterns) {
    out = out.replaceAllMapped(pattern.regex, (m) => pattern.replace(m));
  }
  return out;
}

/// The same, for a nullable value.
String? redactSecretsOrNull(String? text) =>
    text == null ? null : redactSecrets(text);

/// One line for anything thrown: its type and a redacted, clipped message,
/// never the raw `toString()` of an object that may carry request headers.
String describeError(Object error, {int maxChars = 160}) {
  final message = redactSecrets('$error').replaceAll(RegExp(r'\s+'), ' ');
  final clipped =
      message.length <= maxChars ? message : '${message.substring(0, maxChars)}…';
  return '${error.runtimeType}: $clipped';
}

class _Pattern {
  const _Pattern(this.regex, this.replace);
  final RegExp regex;
  final String Function(Match) replace;
}

String _mask(Match _) => '***';

final List<_Pattern> _patterns = [
  // Header lines and header-shaped fragments: keep the name, drop the value.
  _Pattern(
    RegExp(
      r'(authorization|x-goog-api-key|x-api-key|api-key|api_key|apikey)'
      r'''(["']?\s*[:=]\s*["']?)((?:(?:Bearer|Basic)\s+)?[^\s,;"'}]+)''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}${m[2]}***',
  ),
  _Pattern(RegExp(r'Bearer\s+[A-Za-z0-9._~+/=\-]+', caseSensitive: false),
      (m) => 'Bearer ***'),
  // A key passed as a query parameter.
  _Pattern(RegExp(r'([?&]key=)[^&\s"]+', caseSensitive: false),
      (m) => '${m[1]}***'),
  // Vendor prefixes.
  _Pattern(RegExp(r'gsk_[A-Za-z0-9_\-]{6,}'), _mask),
  _Pattern(RegExp(r'AIza[A-Za-z0-9_\-]{10,}'), _mask),
  _Pattern(RegExp(r'csk-[A-Za-z0-9_\-]{6,}'), _mask),
  _Pattern(RegExp(r'sk-[A-Za-z0-9_\-]{16,}'), _mask),
  // Anything long and token-shaped (Mistral keys have no prefix).
  _Pattern(RegExp(r'[A-Za-z0-9_\-+/=]{32,}'), _mask),
];

/// Why a pasted key cannot be stored, or null when it is fine.
///
/// Anything outside printable ASCII in a key ends up in an HTTP header, where
/// Dart throws a `FormatException` **that quotes the header value** — so a key
/// with a stray zero-width space or a smart quote would both fail and leak.
String? apiKeyProblem(String cleaned) {
  if (cleaned.isEmpty) return 'Klíč je prázdný.';
  for (final unit in cleaned.codeUnits) {
    if (unit < 0x21 || unit > 0x7E) {
      return 'Klíč obsahuje nepovolený znak. Zkopíruj ho znovu a vlož bez '
          'mezer a uvozovek.';
    }
  }
  return null;
}

/// A pasted key with everything that is never part of one removed: whitespace
/// (including the no-break space and line breaks a copy from a web page
/// brings), zero-width characters, the byte-order mark, and the quotes a
/// terminal or a JSON snippet wraps it in.
String cleanApiKey(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (_isInvisible(rune)) continue;
    buffer.writeCharCode(rune);
  }
  var cleaned = buffer.toString();
  // Wrapping quotes only — a quote inside would be reported as a bad character.
  while (cleaned.length >= 2 &&
      (cleaned.startsWith('"') && cleaned.endsWith('"') ||
          cleaned.startsWith("'") && cleaned.endsWith("'"))) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }
  return cleaned;
}

bool _isInvisible(int r) =>
    r <= 0x20 ||
    r == 0x7F ||
    (r >= 0x80 && r <= 0xA0) ||
    r == 0xAD ||
    r == 0x1680 ||
    (r >= 0x2000 && r <= 0x200F) ||
    (r >= 0x2028 && r <= 0x202F) ||
    (r >= 0x205F && r <= 0x206F) ||
    r == 0x3000 ||
    r == 0xFEFF;

/// A soft hint about a key that does not look like the service's own, or null.
/// Never blocks saving — vendors change formats, and a school proxy may use its
/// own.
String? apiKeyFormatHint(String service, String cleaned) {
  final lower = service.toLowerCase();
  if (lower.contains('groq') && !cleaned.startsWith('gsk_')) {
    return 'Klíč Groq obvykle začíná „gsk_". Zkontroluj, že jsi vložil správný.';
  }
  if (lower.contains('gemini') && !cleaned.startsWith('AIza')) {
    return 'Klíč Gemini obvykle začíná „AIza". Zkontroluj, že jsi vložil správný.';
  }
  if (lower.contains('cerebras') && !cleaned.startsWith('csk-')) {
    return 'Klíč Cerebras obvykle začíná „csk-". Zkontroluj, že jsi vložil správný.';
  }
  return null;
}

/// What to show the user for something that went wrong: our own messages as
/// they are, anything else reduced to its type and a redacted excerpt. Never
/// `'$e'` — that is how a header value ends up on screen.
String userMessage(Object error) {
  if (error is ApiKeyProblem) return error.message;
  return describeError(error);
}

/// Implemented by exceptions whose [message] is already written for the user
/// and never contains a secret.
abstract interface class ApiKeyProblem implements Exception {
  String get message;
}
