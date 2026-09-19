import '../core/constants.dart';
import '../core/gemini_failure.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import 'course_overview.dart';
import 'course_profile.dart';
import 'llm_provider.dart';
import 'photo_text_service.dart' show geminiFailureText;
import 'syllabus.dart';

/// What „Shrnutí předmětu" ended with: the saved note, or a sentence for the
/// student.
class SubjectSummaryResult {
  const SubjectSummaryResult.saved(int this.noteId) : error = null;
  const SubjectSummaryResult.failed(String this.error) : noteId = null;

  final int? noteId;
  final String? error;
}

/// One overview of a whole subject: every lesson's výpisky read against the
/// thematic plan, saved as a note in the subject.
///
/// Gemini reads everything at once when there is a key; anything else goes
/// through the router with the výpisky cut to an even share per lesson.
/// Never throws — the button gets a result either way.
class SubjectSummaryService {
  SubjectSummaryService(
    this._db, {
    required this._llm,
    this._gemini,
    this._hasGeminiKey,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _tag = 'ai.subject.summary';

  final AppDatabase _db;
  final LlmProvider _llm;
  final LlmProvider? _gemini;
  final Future<bool> Function()? _hasGeminiKey;
  final DateTime Function() _now;

  Future<SubjectSummaryResult> summarize(int subjectId) async {
    try {
      final subject = await _db.subjectsDao.subject(subjectId);
      if (subject == null) {
        return const SubjectSummaryResult.failed('Předmět už neexistuje.');
      }
      final prefs = await _db.preferencesDao.current();
      final topics = await _db.subjectsDao.topics(subjectId);
      final lessons = await (_db.select(_db.meetings)
            ..where((t) => t.subjectId.equals(subjectId)))
          .get();
      lessons.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final notes = <SummaryLesson>[];
      for (final lesson in lessons) {
        final content = (await _db.meetingNotesDao.forMeeting(lesson.id))
            ?.content
            ?.trim();
        if (content == null || content.isEmpty) continue;
        notes.add(
          SummaryLesson(
            date: lesson.createdAt,
            topic: lessonTopic(lesson, topics)?.title,
            notes: content,
          ),
        );
      }
      if (notes.isEmpty) {
        return const SubjectSummaryResult.failed(
          'Zatím tu nejsou žádné výpisky. Vytvoř je nejdřív u jednotlivých '
          'hodin.',
        );
      }

      final now = _now();
      final overview = courseOverview(
        topics: topics,
        lessons: lessons,
        now: now,
      );
      String input(int budget) => subjectSummaryInput(
        course: courseLine(subject, prefs),
        today: now,
        overview: overview,
        lessons: notes,
        budget: budget,
      );

      final content = (await _write(input)).trim();
      if (content.isEmpty) {
        return const SubjectSummaryResult.failed(
          'AI vrátila prázdné shrnutí. Zkus to znovu.',
        );
      }
      final id = await _db.savedNotesDao.saveNote(
        title: 'Shrnutí předmětu – ${subject.name} (${_date(now)})',
        content: content,
        folderId: subjectId,
      );
      AppLog.d(_tag, 'subject $subjectId: ${notes.length} lesson(s) summarised');
      return SubjectSummaryResult.saved(id);
    } on AiException catch (e) {
      AppLog.e(_tag, 'subject $subjectId: summary failed', e);
      return SubjectSummaryResult.failed(_failureText(e));
    } catch (e, st) {
      AppLog.e(_tag, 'subject $subjectId: summary failed', e, st);
      return const SubjectSummaryResult.failed(
        'Shrnutí se nepodařilo. Zkus to znovu.',
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
          timeout: kSubjectSummaryTimeout,
        );
        if (text.trim().isNotEmpty) return text;
      } on AiException catch (e) {
        // A bad key is the student's to fix; hiding it behind the router
        // would leave Gemini silently unused for good.
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

  static String _failureText(AiException e) {
    if (e.kind is GeminiErrorKind) return geminiFailureText(e);
    if (e is AiTransientException) {
      return 'AI služby teď neodpovídají (limit nebo síť). Zkus to za chvíli '
          'znovu.';
    }
    if (e.message.startsWith('No Groq API key')) {
      return 'Chybí AI klíč. Přidej ho v Nastavení.';
    }
    return e.statusCode == null
        ? 'AI nevrátila použitelné shrnutí. Zkus to znovu.'
        : 'AI požadavek odmítla (HTTP ${e.statusCode}).';
  }

  static const String _systemPrompt = '''
A student records their school lessons and keeps study notes ("výpisky") from
each one. You get the course (subject, school, year), the subject's thematic
plan with the status of every topic, and the výpisky of every recorded lesson,
oldest first.

Write an overview of the whole course so far, in Czech, pitched at this
student's level. Plain text only: short heading lines ending with a colon,
"- " bullets, no Markdown, no tables.

Use exactly these three sections, in this order:

Co jsme probrali:
- the course so far, grouped by the plan's topics, with the key terms and
  facts from the výpisky — a revision sheet, not a list of dates.

Co chybí podle plánu:
- topics the plan has already reached ("Chybí záznam" or "Teď") that no
  recorded lesson covered, with what the plan lists for them — say it is what
  the plan says, not what was taught. If nothing is missing, say so in one
  line.

Na co se zaměřit před testem:
- 4–8 concrete points: the terms, rules and connections most likely to be
  tested, taken from the výpisky first.

Facts about what was taught come only from the výpisky; the plan says what
should be taught, not what was. Topics marked "Před nahráváním" were taught
before the student started recording — never call them missing. Do not invent
lessons, dates, grades or homework.''';
}

/// One lesson's výpisky as the summary reads them.
class SummaryLesson {
  const SummaryLesson({required this.date, required this.notes, this.topic});

  final DateTime date;
  final String? topic;
  final String notes;
}

/// The user message of a summary request: the course, the plan with each
/// topic's status, then the lessons' výpisky cut to [budget] characters in
/// total by [evenShare].
String subjectSummaryInput({
  required String course,
  required DateTime today,
  required CourseOverview overview,
  required List<SummaryLesson> lessons,
  required int budget,
}) {
  final plan = StringBuffer();
  if (overview.topics.isEmpty) {
    plan.writeln('(tematický plán není zadaný)');
  }
  for (var i = 0; i < overview.topics.length; i++) {
    final t = overview.topics[i];
    final lessonsNote = t.lessons.isEmpty
        ? ''
        : ' (${t.lessons.length}× hodina)';
    plan.writeln(
      '${i + 1}. ${t.topic.title} — ${coverageLabel(t.coverage)}$lessonsNote',
    );
    final terms = t.topic.terms?.trim();
    if (terms != null && terms.isNotEmpty) plan.writeln('   Pojmy: $terms');
  }

  final cut = evenShare([for (final l in lessons) l.notes], budget);
  final notes = StringBuffer();
  for (var i = 0; i < lessons.length; i++) {
    final l = lessons[i];
    final topic = l.topic == null ? '' : ' · téma: ${l.topic}';
    notes
      ..writeln('=== Hodina ${_date(l.date)}$topic ===')
      ..writeln(cut[i])
      ..writeln();
  }

  return 'Kurz: $course\n'
      'Dnes: ${_date(today)}\n\n'
      'Tematický plán (v pořadí výuky):\n$plan\n'
      'Výpisky z hodin (od nejstarší):\n\n$notes'.trimRight();
}

/// Cuts [texts] to [budget] characters in total, evenly: a text shorter than
/// its share keeps all of itself and leaves the rest to the longer ones. A cut
/// text ends at a line break where one is near, and says it was cut.
List<String> evenShare(List<String> texts, int budget) {
  final order = [for (var i = 0; i < texts.length; i++) i]
    ..sort((a, b) => texts[a].length.compareTo(texts[b].length));
  final out = List<String>.of(texts);
  var left = budget;
  for (var k = 0; k < order.length; k++) {
    final i = order[k];
    final share = left ~/ (order.length - k);
    if (texts[i].length > share) out[i] = _cut(texts[i], share);
    left -= out[i].length;
  }
  return out;
}

const _cutMark = '\n[…]';

String _cut(String text, int max) {
  final room = max - _cutMark.length;
  if (room <= 0) return '';
  var head = text.substring(0, room);
  final line = head.lastIndexOf('\n');
  if (line > room ~/ 2) head = head.substring(0, line);
  return '${head.trimRight()}$_cutMark';
}

String _date(DateTime d) => '${d.day}. ${d.month}. ${d.year}';
