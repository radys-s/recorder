import '../ai/llm_provider.dart';
import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/study_cards_table.dart';
import '../ai/gemini_first.dart';
import 'study_items.dart';

/// Longest note text sent to the model when the note has no „Co si
/// zapamatovat" section and the whole note is used instead.
const int kStudyNoteMaxChars = 12000;

/// Turns výpisky into study cards.
///
/// „Klíčové pojmy" become cards for free. „Co si zapamatovat" (or, for a note
/// without that section, the whole note) goes through one model call that
/// writes question–answer pairs. A failed call keeps the free cards.
class StudyCardGenerator {
  StudyCardGenerator(
    this._db, {
    required this._llm,
    this._gemini,
    this._hasGeminiKey,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _tag = 'learning.generate';

  final AppDatabase _db;
  final LlmProvider _llm;
  final LlmProvider? _gemini;
  final Future<bool> Function()? _hasGeminiKey;
  final DateTime Function() _now;

  /// After a lesson's výpisky are stored. Never throws; returns cards added.
  Future<int> fromLessonNotes(int meetingId, String notes) async {
    try {
      final meeting = await (_db.select(
        _db.meetings,
      )..where((t) => t.id.equals(meetingId))).getSingleOrNull();
      final subjectId = meeting?.subjectId;
      if (subjectId == null) return 0;
      return await _generate(
        subjectId,
        notes,
        meetingId: meetingId,
        // Heslovitě and Jen to hlavní have no „Co si zapamatovat" section;
        // they are short, so the whole of them is what there is to learn.
        wholeNoteFallback: true,
      );
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: study cards failed', e, st);
      return 0;
    }
  }

  /// „Vytvořit kartičky" on a saved note. Throws an [AiException] when the
  /// model call fails and nothing could be made without it, so the screen can
  /// say why.
  Future<int> fromSavedNote(SavedNote note) {
    final subjectId = note.folderId;
    if (subjectId == null) {
      throw StateError('Poznámka nepatří k žádnému předmětu.');
    }
    return _generate(
      subjectId,
      note.content,
      noteId: note.id,
      meetingId: note.meetingId,
      wholeNoteFallback: true,
      rethrowAi: true,
    );
  }

  Future<int> _generate(
    int subjectId,
    String notes, {
    int? meetingId,
    int? noteId,
    required bool wholeNoteFallback,
    bool rethrowAi = false,
  }) async {
    final subject = await _db.subjectsDao.subject(subjectId);
    if (subject == null) return 0;
    final terms = termCardsFromNotes(notes);
    var added = await _db.studyCardsDao.addCards(
      subjectId,
      terms,
      meetingId: meetingId,
      noteId: noteId,
      now: _now(),
    );

    final bullets = rememberBulletsFromNotes(notes);
    String? input;
    if (bullets.isNotEmpty) {
      input = 'Co si zapamatovat:\n${bullets.map((b) => '- $b').join('\n')}';
    } else if (wholeNoteFallback && notes.trim().isNotEmpty) {
      final text = notes.trim();
      input = text.length <= kStudyNoteMaxChars
          ? text
          : text.substring(0, kStudyNoteMaxChars);
    }
    if (input == null) return added;

    try {
      final useGemini = _gemini != null && await _geminiAvailable();
      Future<String> ask(LlmProvider llm, String model) => llm.complete(
        model: model,
        messages: [
          const LlmMessage.system(_systemPrompt),
          LlmMessage.user(
            'Předmět: ${subject.name}\n'
            'Hotové kartičky (neopakuj): '
            '${terms.isEmpty ? '(žádné)' : terms.map((t) => t.front).join(', ')}\n\n'
            '$input',
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
        onRouter: () => ask(_llm, kGroqNotesModel),
      );
      added += await _db.studyCardsDao.addCards(
        subjectId,
        parseStudyPairs(raw, StudySource.remember),
        meetingId: meetingId,
        noteId: noteId,
        now: _now(),
      );
    } on AiException catch (e, st) {
      AppLog.e(_tag, 'subject $subjectId: pairs failed', e, st);
      if (rethrowAi && added == 0) rethrow;
    }
    AppLog.d(_tag, 'subject $subjectId: $added card(s) added');
    return added;
  }

  Future<bool> _geminiAvailable() async {
    try {
      return await _hasGeminiKey?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  static const String _systemPrompt = '''
A student reviews study cards (spaced repetition) for a school subject. Turn
the notes below into question–answer cards they can test themselves on.

Rules:
- One fact per card. The question must make sense on its own, without the
  notes, and must have one clear answer.
- The answer is short: a word, a name, a number, or one sentence.
- Use only what the notes say. Add nothing, guess nothing.
- Write in the notes' language.
- Skip anything already covered by the finished cards listed.
- At most 12 cards; fewer is fine.

Reply with one JSON object and nothing else:
{"cards": [{"q": "...", "a": "..."}]}''';
}
