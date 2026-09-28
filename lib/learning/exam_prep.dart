import '../ai/course_profile.dart';
import '../ai/json_extract.dart';
import '../ai/llm_provider.dart';
import '../ai/photo_text_service.dart' show geminiFailureText;
import '../ai/subject_summary_service.dart' show SummaryLesson, evenShare;
import '../ai/syllabus.dart';
import '../core/constants.dart';
import '../core/gemini_failure.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/study_cards_dao.dart';
import '../data/db/tables/study_cards_table.dart';

/// Most questions one „Před testem" run asks.
const int kExamQuestionCount = 10;

enum ExamQuestionKind { choice, open }

/// One quiz question. A choice question is marked by the app; an open one is
/// revealed and the student says whether they knew it.
class ExamQuestion {
  const ExamQuestion({
    required this.kind,
    required this.question,
    required this.answer,
    this.options = const [],
    this.correct,
    this.explanation = '',
  });

  final ExamQuestionKind kind;
  final String question;

  /// The right answer as text; for a choice question, the right option.
  final String answer;
  final List<String> options;
  final int? correct;
  final String explanation;
}

/// What the student should know, and the questions that check it.
class ExamPrep {
  const ExamPrep({required this.summary, required this.questions});

  final String summary;
  final List<ExamQuestion> questions;
}

/// Reads the model's reply; null when nothing usable came back.
///
/// Malformed questions are skipped one by one rather than failing the run: a
/// choice question needs 2–5 distinct options and a valid index, an open one a
/// question and an answer.
ExamPrep? parseExamPrep(String raw) {
  final json = extractJsonObject(raw);
  if (json == null) return null;
  final summary = _text(json['summary']);
  final list = json['questions'];
  final questions = <ExamQuestion>[];
  final seen = <String>{};
  if (list is List) {
    for (final item in list) {
      if (questions.length >= kExamQuestionCount) break;
      if (item is! Map) continue;
      final q = _text(item['q'] ?? item['question']);
      if (q.isEmpty || !seen.add(q.toLowerCase())) continue;
      final explanation = _text(item['explanation']);
      final options = item['options'];
      final correct = item['correct'];
      if (options is List && options.isNotEmpty) {
        final opts = [for (final o in options) _text(o)];
        final distinct = {for (final o in opts) o.toLowerCase()};
        if (opts.length < 2 ||
            opts.length > 5 ||
            opts.any((o) => o.isEmpty) ||
            distinct.length != opts.length ||
            correct is! int ||
            correct < 0 ||
            correct >= opts.length) {
          continue;
        }
        questions.add(
          ExamQuestion(
            kind: ExamQuestionKind.choice,
            question: q,
            options: opts,
            correct: correct,
            answer: opts[correct],
            explanation: explanation,
          ),
        );
      } else {
        final a = _text(item['a'] ?? item['answer']);
        if (a.isEmpty) continue;
        questions.add(
          ExamQuestion(
            kind: ExamQuestionKind.open,
            question: q,
            answer: a,
            explanation: explanation,
          ),
        );
      }
    }
  }
  if (questions.isEmpty) return null;
  return ExamPrep(summary: summary, questions: questions);
}

String _text(Object? v) => v is String ? v.trim() : '';

/// The user message: the course, the chosen topics, then the výpisky cut to
/// [budget] characters in total.
String examPrepInput({
  required String course,
  required List<SyllabusTopic> topics,
  required List<SummaryLesson> lessons,
  required int budget,
}) {
  final buf = StringBuffer('Kurz: $course\n\n');
  if (topics.isEmpty) {
    buf.writeln('Test: celé dosavadní učivo');
  } else {
    buf.writeln('Test z témat:');
    for (final t in topics) {
      final terms = t.terms?.trim();
      buf.writeln(
        '- ${t.title}${terms == null || terms.isEmpty ? '' : ' (pojmy: $terms)'}',
      );
    }
  }
  buf.writeln('\nVýpisky z hodin (od nejstarší):\n');
  final cut = evenShare([for (final l in lessons) l.notes], budget);
  for (var i = 0; i < lessons.length; i++) {
    final l = lessons[i];
    final topic = l.topic == null ? '' : ' · téma: ${l.topic}';
    buf
      ..writeln('=== Hodina ${_date(l.date)}$topic ===')
      ..writeln(cut[i])
      ..writeln();
  }
  return buf.toString().trimRight();
}

/// A prepared run, or a sentence for the student.
class ExamPrepResult {
  const ExamPrepResult.ready(ExamPrep this.prep) : error = null;
  const ExamPrepResult.failed(String this.error) : prep = null;

  final ExamPrep? prep;
  final String? error;
}

/// One answered question.
class ExamAnswer {
  const ExamAnswer(this.question, {required this.correct, this.given});

  final ExamQuestion question;
  final bool correct;

  /// The option the student picked; null for an open question.
  final String? given;
}

/// „Před testem": a revision summary and a quiz from the subject's výpisky.
///
/// Gemini reads everything when there is a key; otherwise, or when Gemini
/// fails for anything but a bad key, the router gets the výpisky cut to an
/// even share per lesson. [prepare] never throws.
class ExamPrepService {
  ExamPrepService(
    this._db, {
    required this._llm,
    this._gemini,
    this._hasGeminiKey,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _tag = 'learning.exam';

  final AppDatabase _db;
  final LlmProvider _llm;
  final LlmProvider? _gemini;
  final Future<bool> Function()? _hasGeminiKey;
  final DateTime Function() _now;

  /// Lessons with výpisky, optionally only those of [topicIds].
  Future<List<SummaryLesson>> _lessons(
    int subjectId,
    List<SyllabusTopic> topics,
    Set<int> topicIds,
  ) async {
    final lessons = await (_db.select(
      _db.meetings,
    )..where((t) => t.subjectId.equals(subjectId))).get();
    lessons.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final out = <SummaryLesson>[];
    for (final lesson in lessons) {
      final topic = lessonTopic(lesson, topics);
      if (topicIds.isNotEmpty && !topicIds.contains(topic?.id)) continue;
      final notes = (await _db.meetingNotesDao.forMeeting(lesson.id))?.content
          ?.trim();
      if (notes == null || notes.isEmpty) continue;
      out.add(
        SummaryLesson(
          date: lesson.createdAt,
          topic: topic?.title,
          notes: notes,
        ),
      );
    }
    return out;
  }

  Future<ExamPrepResult> prepare(
    int subjectId, {
    Set<int> topicIds = const {},
  }) async {
    try {
      final subject = await _db.subjectsDao.subject(subjectId);
      if (subject == null) {
        return const ExamPrepResult.failed('Předmět už neexistuje.');
      }
      final prefs = await _db.preferencesDao.current();
      final topics = await _db.subjectsDao.topics(subjectId);
      final lessons = await _lessons(subjectId, topics, topicIds);
      if (lessons.isEmpty) {
        return ExamPrepResult.failed(
          topicIds.isEmpty
              ? 'Zatím tu nejsou žádné výpisky. Vytvoř je nejdřív u hodin.'
              : 'K vybraným tématům nejsou výpisky. Zkus vybrat víc témat.',
        );
      }
      String input(int budget) => examPrepInput(
        course: courseLine(subject, prefs),
        topics: [
          for (final t in topics)
            if (topicIds.contains(t.id)) t,
        ],
        lessons: lessons,
        budget: budget,
      );
      final prep = parseExamPrep(await _write(input));
      if (prep == null) {
        return const ExamPrepResult.failed(
          'AI nevrátila použitelné otázky. Zkus to znovu.',
        );
      }
      AppLog.d(
        _tag,
        'subject $subjectId: ${prep.questions.length} question(s)',
      );
      return ExamPrepResult.ready(prep);
    } on AiException catch (e) {
      AppLog.e(_tag, 'subject $subjectId: preparation failed', e);
      return ExamPrepResult.failed(_failureText(e));
    } catch (e, st) {
      AppLog.e(_tag, 'subject $subjectId: preparation failed', e, st);
      return const ExamPrepResult.failed(
        'Příprava se nepodařila. Zkus to znovu.',
      );
    }
  }

  Future<String> _write(String Function(int budget) input) async {
    final gemini = _gemini;
    if (gemini != null && await _geminiAvailable()) {
      try {
        final text = await gemini.complete(
          model: kGeminiModel,
          messages: [
            const LlmMessage.system(_systemPrompt),
            LlmMessage.user(input(kSubjectSummaryGeminiChars)),
          ],
          maxTokens: 12000,
          jsonMode: true,
          timeout: kSubjectSummaryTimeout,
        );
        if (parseExamPrep(text) != null) return text;
      } on AiException catch (e) {
        if (e.kind == GeminiErrorKind.badKey) rethrow;
        AppLog.e(_tag, 'Gemini failed, asking the router', e);
      }
    }
    return _llm.complete(
      model: kGroqNotesModel,
      messages: [
        const LlmMessage.system(_systemPrompt),
        LlmMessage.user(input(kSubjectSummaryRouterChars)),
      ],
      maxTokens: 6000,
      jsonMode: true,
      timeout: kSubjectSummaryTimeout,
    );
  }

  Future<bool> _geminiAvailable() async {
    try {
      return await _hasGeminiKey?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Saves the run as a note in the subject; returns its id.
  Future<int> saveResult(
    int subjectId,
    ExamPrep prep,
    List<ExamAnswer> answers,
  ) async {
    final subject = await _db.subjectsDao.subject(subjectId);
    final right = answers.where((a) => a.correct).length;
    final buf = StringBuffer();
    if (prep.summary.isNotEmpty) {
      buf
        ..writeln('Co umět:')
        ..writeln(prep.summary)
        ..writeln();
    }
    buf.writeln('Kvíz ($right z ${answers.length}):');
    for (final a in answers) {
      buf.writeln(
        '- ${a.correct ? 'Správně' : 'Chyba'}: ${a.question.question} '
        '— ${a.question.answer}',
      );
    }
    return _db.savedNotesDao.saveNote(
      title: 'Před testem – ${subject?.name ?? 'předmět'} (${_date(_now())})',
      content: buf.toString().trimRight(),
      folderId: subjectId,
    );
  }

  /// Wrong answers become study cards; returns how many were new.
  Future<int> addMistakes(int subjectId, List<ExamAnswer> answers) {
    return _db.studyCardsDao.addCards(subjectId, [
      for (final a in answers)
        if (!a.correct)
          StudyItem(
            a.question.question,
            a.question.explanation.isEmpty
                ? a.question.answer
                : '${a.question.answer}\n\n${a.question.explanation}',
            StudySource.quiz,
          ),
    ], now: _now());
  }

  static String _failureText(AiException e) {
    if (e.kind is GeminiErrorKind) return geminiFailureText(e);
    if (e is AiTransientException) {
      return 'AI služby teď neodpovídají (limit nebo síť). Zkus to za chvíli '
          'znovu.';
    }
    if (e.message.startsWith('No Groq API key')) {
      return 'Chybí AI klíč. Přidej ho v Nastavení.';
    }
    return 'AI požadavek se nepodařil. Zkus to znovu.';
  }

  static const String _systemPrompt = '''
A student has a test soon. You get the course (subject, school, year), the
topics the test covers (or "celé dosavadní učivo") and the study notes
("výpisky") of the recorded lessons, oldest first.

Write in Czech, pitched at this student's level. Use only what the výpisky say;
never invent facts, dates or names.

1. "summary": what to know for the test — plain text, "- " bullets, 6–12 lines,
   the key terms, rules and connections. No Markdown.
2. "questions": exactly 10 questions that check that knowledge. About 7 are
   multiple choice with 4 short options, one correct, the wrong ones plausible;
   the rest are open questions with a short model answer (a word, a name, a
   number or one sentence). Every question must make sense on its own. Give
   each a one-sentence explanation of why the answer is right.

Reply with one JSON object and nothing else:
{"summary": "...", "questions": [
  {"q": "...", "options": ["...", "...", "...", "..."], "correct": 0,
   "explanation": "..."},
  {"q": "...", "a": "...", "explanation": "..."}]}''';
}

String _date(DateTime d) => '${d.day}. ${d.month}. ${d.year}';
