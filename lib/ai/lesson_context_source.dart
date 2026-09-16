
import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../data/db/tables/chat_messages_table.dart';
import '../stt/glossary.dart';
import 'context_builder.dart';
import 'lesson_notes_input.dart';

/// Reads what the student gave the AI for one lesson.
///
/// A class rather than a function so the answer services can be tested with a
/// fake (`implements LessonContextSource`) instead of a database.
class LessonContextSource {
  LessonContextSource(this._db);

  final AppDatabase _db;

  /// Everything for [meetingId]. Empty for an ordinary meeting with no rules
  /// anywhere, which keeps the meeting prompt exactly as it was.
  Future<LessonMaterial> load(int meetingId) async {
    final meeting = await (_db.select(_db.meetings)
          ..where((t) => t.id.equals(meetingId)))
        .getSingleOrNull();
    final prefs = await _db.preferencesDao.current();

    final subjectId = meeting?.subjectId;
    final subject =
        subjectId == null ? null : await _db.subjectsDao.subject(subjectId);

    final chat = await _db.chatMessagesDao.messages(meetingId);
    final userChat = [
      for (final m in chat)
        if (m.role == ChatRole.user &&
            m.status == ChatStatus.ready &&
            m.body.trim().isNotEmpty)
          m,
    ];

    final cards = <LessonCard>[];
    if (subject != null) {
      final pinned = (await _db.subjectsDao.pinnedCardIds(meetingId)).toSet();
      final all = await _db.subjectsDao.cards(subject.id);
      for (final pinnedFirst in [true, false]) {
        for (final c in all) {
          if (pinned.contains(c.id) != pinnedFirst) continue;
          cards.add(LessonCard(
            id: c.id,
            title: c.title,
            content: c.content,
            summary: c.summary,
            pinned: pinnedFirst,
          ));
        }
      }
    }

    return LessonMaterial(
      subjectName: subject?.name,
      globalRules: prefs.globalRules,
      subjectRules: subject?.rules,
      lessonRules: meeting?.rules,
      chatRules: [
        for (final m in userChat)
          if (m.intent == ChatIntent.rule) m.body,
      ],
      chatContext: [
        for (final m in userChat)
          if (m.intent == ChatIntent.context)
            m.body
          else if (m.intent == ChatIntent.photo)
            m.short == null
                ? 'Photo of the board:\n${m.body}'
                : 'Photo of the board (${m.short}):\n${m.body}',
      ],
      cards: cards,
    );
  }

  /// What výpisky are made from besides the transcript, or null for a meeting
  /// without a subject.
  Future<LessonNotesInput?> notesInput(int meetingId) async {
    final meeting = await (_db.select(_db.meetings)
          ..where((t) => t.id.equals(meetingId)))
        .getSingleOrNull();
    final subjectId = meeting?.subjectId;
    if (subjectId == null) return null;
    final subject = await _db.subjectsDao.subject(subjectId);
    if (subject == null) return null;

    final pinned = (await _db.subjectsDao.pinnedCardIds(meetingId)).toSet();
    final cards = await _db.subjectsDao.cards(subjectId);
    final chat = await _db.chatMessagesDao.messages(meetingId);
    final answerCards = await (_db.select(_db.answerCards)
          ..where((t) => t.meetingId.equals(meetingId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    final ready = [
      for (final m in chat)
        if (m.status == ChatStatus.ready) m,
    ];
    final questions = <({int atMs, String question, String answer})>[];
    for (final m in ready) {
      if (m.role != ChatRole.user ||
          m.intent != ChatIntent.question ||
          m.body.trim().isEmpty) {
        continue;
      }
      final reply = ready
          .where((r) => r.role == ChatRole.assistant && r.replyTo == m.id)
          .lastOrNull;
      final answer = _answerText(reply?.short, reply?.detail);
      if (answer.isEmpty) continue;
      questions.add((atMs: m.atMs, question: m.body, answer: answer));
    }
    final segments =
        await _db.transcriptSegmentsDao.segmentsForMeeting(meetingId);
    final segmentStart = {for (final s in segments) s.id: s.startMs};
    for (final c in answerCards) {
      final answer = _answerText(c.answer, c.detail);
      if (c.question.trim().isEmpty || answer.isEmpty) continue;
      questions.add((
        atMs: segmentStart[c.segmentId] ?? 0,
        question: c.question,
        answer: answer,
      ));
    }
    // Chat questions and automatic answers interleaved in lesson order; the
    // index keeps the sort stable for equal offsets.
    final order = {for (var i = 0; i < questions.length; i++) questions[i]: i};
    questions.sort((a, b) {
      final byTime = a.atMs.compareTo(b.atMs);
      return byTime != 0 ? byTime : order[a]!.compareTo(order[b]!);
    });

    return LessonNotesInput(
      subjectName: subject.name,
      cardTitles: [
        for (final c in cards)
          if (pinned.contains(c.id)) c.title,
      ],
      context: [
        for (final m in ready)
          if (m.role == ChatRole.user &&
              m.intent == ChatIntent.context &&
              m.body.trim().isNotEmpty)
            m.body.trim(),
      ],
      photos: [
        for (final m in ready)
          if (m.intent == ChatIntent.photo && m.body.trim().isNotEmpty)
            m.short == null || m.short!.trim().isEmpty
                ? m.body.trim()
                : '${m.short!.trim()}\n${m.body.trim()}',
      ],
      questions: [
        for (final q in questions) (question: q.question, answer: q.answer),
      ],
    );
  }

  static String _answerText(String? short, String? detail) {
    final s = short?.trim() ?? '';
    final d = detail?.trim() ?? '';
    if (d.isEmpty) return s;
    if (s.isEmpty) return d;
    return '$s $d';
  }

  /// Names and terms from the lesson's pinned cards, for Whisper.
  Future<String?> glossary(int meetingId) async {
    final ids = await _db.subjectsDao.pinnedCardIds(meetingId);
    if (ids.isEmpty) return null;
    final rows = await (_db.select(_db.contextCards)
          ..where((t) => t.id.isIn(ids)))
        .get();
    return buildWhisperGlossary([
      for (final c in rows)
        (title: c.title, content: c.content, keywords: c.keywords),
    ]);
  }

  Future<void> markUsed(int cardId) =>
      _db.subjectsDao.markCardsUsed([cardId], DateTime.now());
}
