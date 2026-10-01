import 'dart:convert';

import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/subjects_dao.dart';
import '../data/db/tables/meeting_notes_table.dart';
import '../stt/transcript_sanitizer.dart';
import 'gemini_first.dart';
import 'json_extract.dart';
import 'llm_provider.dart';

/// At most this many suggestions come out of one set of notes.
const int kMaxCardSuggestions = 3;

/// A topic from a lesson worth keeping as a card of its own.
class CardSuggestion {
  const CardSuggestion({required this.title, required this.content});

  final String title;
  final String content;

  @override
  bool operator ==(Object other) =>
      other is CardSuggestion &&
      other.title == title &&
      other.content == content;

  @override
  int get hashCode => Object.hash(title, content);
}

/// Suggestions from a model reply: at most [kMaxCardSuggestions], none with an
/// empty title or content, and none whose title matches an existing card or an
/// earlier suggestion (compared without case and diacritics).
List<CardSuggestion> parseCardSuggestions(
  String raw,
  Iterable<String> existingTitles,
) {
  final decoded = extractJsonObject(raw);
  final list = decoded?['cards'];
  if (list is! List) return const [];

  final taken = {for (final t in existingTitles) normalizeForArtifactMatch(t)};
  final out = <CardSuggestion>[];
  for (final item in list) {
    if (out.length == kMaxCardSuggestions) break;
    if (item is! Map) continue;
    final title = _text(item['title'], SubjectsDao.maxCardTitleLength);
    final content = _text(item['content'], kCardSuggestionMaxChars);
    if (title.isEmpty || content.isEmpty) continue;
    final key = normalizeForArtifactMatch(title);
    if (key.isEmpty || !taken.add(key)) continue;
    out.add(CardSuggestion(title: title, content: content));
  }
  return out;
}

String _text(Object? value, int max) {
  final text = value is String ? value.trim() : '';
  return text.length <= max ? text : text.substring(0, max).trimRight();
}

/// The stored form; null for no suggestions, so the column stays empty.
String? encodeCardSuggestions(List<CardSuggestion> suggestions) =>
    suggestions.isEmpty
        ? null
        : jsonEncode([
            for (final s in suggestions) {'title': s.title, 'content': s.content},
          ]);

/// The stored form read back; anything malformed is skipped, never thrown.
List<CardSuggestion> decodeCardSuggestions(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map &&
            item['title'] is String &&
            item['content'] is String)
          CardSuggestion(
            title: item['title'] as String,
            content: item['content'] as String,
          ),
    ];
  } catch (_) {
    return const [];
  }
}

/// After a lesson's notes are ready, proposes 0–3 topics for new cards.
///
/// Optional in every sense: a failure is logged and the notes stay exactly as
/// they are.
class CardSuggestionService {
  CardSuggestionService(
    this._db, {
    required this._groq,
    this._gemini,
    this._hasGeminiKey,
  });

  static const _tag = 'ai.cards.suggest';

  final AppDatabase _db;
  final LlmProvider _groq;
  final LlmProvider? _gemini;
  final Future<bool> Function()? _hasGeminiKey;

  /// Stores suggestions for [meetingId] made from [notes]. Never throws.
  Future<void> suggest(int meetingId, String notes) async {
    try {
      final meeting = await (_db.select(_db.meetings)
            ..where((t) => t.id.equals(meetingId)))
          .getSingleOrNull();
      final subjectId = meeting?.subjectId;
      if (subjectId == null) return;
      final subject = await _db.subjectsDao.subject(subjectId);
      if (subject == null) return;
      final titles = [
        for (final c in await _db.subjectsDao.cards(subjectId)) c.title,
      ];

      var useGemini = _gemini != null && await _geminiAvailable();
      Future<String> ask(LlmProvider llm, String model) => llm.complete(
        model: model,
        messages: [
          const LlmMessage.system(_systemPrompt),
          LlmMessage.user(
            'Předmět: ${subject.name}\n\n'
            'Existující karty:\n'
            '${titles.isEmpty ? '(žádné)' : titles.map((t) => '- $t').join('\n')}\n\n'
            'Výpisky z hodiny:\n$notes',
          ),
        ],
        temperature: 0.2,
        maxTokens: 3000,
        jsonMode: true,
        timeout: kCardSuggestionTimeout,
      );
      final raw = await geminiFirst(
        preferGemini: useGemini,
        tag: _tag,
        onGemini: () => ask(_gemini!, kGeminiLiteModel),
        onRouter: () {
          useGemini = false;
          return ask(_groq, kGroqNotesModel);
        },
      );
      final suggestions = parseCardSuggestions(raw, titles);

      // Only onto the notes they were made from: a regenerate in the meantime
      // has its own suggestions coming.
      final row = await _db.meetingNotesDao.forMeeting(meetingId);
      if (row == null ||
          row.status != NotesStatus.ready ||
          row.content?.trim() != notes.trim()) {
        return;
      }
      await _db.meetingNotesDao
          .setCardSuggestions(meetingId, encodeCardSuggestions(suggestions));
      AppLog.d(_tag,
          'meeting $meetingId: ${suggestions.length} suggestion(s) on ${useGemini ? 'Gemini' : 'Groq'}');
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: suggestions failed', e, st);
    }
  }

  Future<bool> _geminiAvailable() async {
    try {
      return await _hasGeminiKey?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  static const String _systemPrompt = '''
A student keeps study cards per school subject; the AI reads them in later
lessons. Given the notes from one lesson and the titles of the cards that
already exist, propose at most 3 new cards worth keeping.

A good card is one topic that will come back: a work of literature, an author,
a period or movement, a law or theorem, a process, a set of related terms. Not
the lesson itself, not homework, not a topic an existing card already covers
under another wording. Proposing nothing is a fine answer.

Reply with one JSON object and nothing else:
{"cards": [{"title": "...", "content": "..."}]}

"title": short, like the existing titles. "content": what the notes say about
the topic, in the notes' language, as plain text with "- " bullets — only facts
from the notes, nothing added.''';
}
