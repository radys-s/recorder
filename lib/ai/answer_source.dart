import 'dart:convert';

import '../core/constants.dart';

/// One page a web-backed answer was drawn from.
///
/// Stored on the answer card as a JSON array rather than in a table of its
/// own: there are at most [kMaxAnswerSources] of them, nothing ever queries
/// across them, and a nullable text column needs no migration for the rows
/// that already exist.
const String kGeminiRedirectHost = 'vertexaisearch.cloud.google.com';

class AnswerSource {
  const AnswerSource({required this.title, required this.url});

  final String title;
  final Uri url;

  /// What the chip says. A domain is what tells the reader whether to trust
  /// the answer — a page title from a search result is often the same clickbait
  /// for every hit, and rarely fits a chip anyway.
  ///
  /// Gemini's grounding links all point at one Google redirect host, and the
  /// real site is only in the title it gives them, so there the title is used.
  String get domain {
    final host = url.host == kGeminiRedirectHost && title.isNotEmpty
        ? title.toLowerCase()
        : url.host;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  Map<String, String> toJson() => {'title': title, 'url': url.toString()};

  /// Null for anything that is not a usable http(s) link.
  ///
  /// The model reports its own sources, so this is where a hallucinated or
  /// half-written URL is supposed to die — a chip that cannot be opened is
  /// worse than one that is not there, because it looks like evidence.
  static AnswerSource? tryParse(Object? raw) {
    if (raw is! Map) return null;

    final url = Uri.tryParse('${raw['url'] ?? ''}'.trim());
    if (url == null || !url.hasScheme || url.host.isEmpty) return null;
    if (url.scheme != 'http' && url.scheme != 'https') return null;

    final title = '${raw['title'] ?? ''}'.trim();
    return AnswerSource(title: title.isEmpty ? url.host : title, url: url);
  }
}

/// The stored form: a JSON array, or null when there are none. Null rather
/// than `[]` so "this answer had no sources" and "this answer predates web
/// search" read the same in the UI, which is the only thing either means.
String? encodeAnswerSources(List<AnswerSource> sources) =>
    sources.isEmpty ? null : jsonEncode([for (final s in sources) s.toJson()]);

/// Never throws: a row written by an older or buggier version of this code is
/// an answer with no sources, not a screen that fails to build mid-meeting.
List<AnswerSource> decodeAnswerSources(String? stored) {
  if (stored == null || stored.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(stored);
    if (decoded is! List) return const [];
    return [for (final entry in decoded) ?AnswerSource.tryParse(entry)];
  } catch (_) {
    return const [];
  }
}

/// Every source that can be dug out of an arbitrary JSON tree, in the order it
/// is met, de-duplicated by domain and capped at [max].
///
/// Written as a blind walk rather than against a documented shape on purpose:
/// this is fed the `executed_tools` block of Groq's agentic models, whose
/// layout is theirs to change, and which nests one level deeper as a JSON
/// *string* under `output`. A walk that looks for any object carrying a usable
/// link keeps working through both. Anything it does not recognise yields no
/// sources, which is a card without chips — the degradation this whole feature
/// is built to fall back to.
List<AnswerSource> collectAnswerSources(
  Object? node, {
  int max = kMaxAnswerSources,
}) {
  final found = <AnswerSource>[];

  void walk(Object? value, int depth) {
    if (found.length >= max || depth > 8) return;

    if (value is List) {
      for (final child in value) {
        walk(child, depth + 1);
      }
      return;
    }

    if (value is String) {
      // `output` arrives as a JSON document inside a string field.
      final trimmed = value.trimLeft();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          walk(jsonDecode(value), depth + 1);
        } catch (_) {
          // Not JSON after all; a plain string carries no source.
        }
      }
      return;
    }

    if (value is! Map) return;

    final source = AnswerSource.tryParse({
      'url': value['url'] ?? value['link'] ?? '',
      'title': value['title'] ?? value['name'] ?? '',
    });
    if (source != null && !found.any((s) => s.domain == source.domain)) {
      found.add(source);
      if (found.length >= max) return;
    }

    for (final child in value.values) {
      walk(child, depth + 1);
    }
  }

  walk(node, 0);
  return found;
}
