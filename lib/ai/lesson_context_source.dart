import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../data/db/tables/chat_messages_table.dart';
import '../stt/lesson_vocabulary.dart';
import '../stt/term_corrections.dart';
import 'context_builder.dart';
import 'course_profile.dart';
import 'lesson_notes_input.dart';
import 'syllabus.dart';

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
    final meeting = await (_db.select(
      _db.meetings,
    )..where((t) => t.id.equals(meetingId))).getSingleOrNull();
    final prefs = await _db.preferencesDao.current();

    final subjectId = meeting?.subjectId;
    final subject = subjectId == null
        ? null
        : await _db.subjectsDao.subject(subjectId);
    final topic = meeting == null || subjectId == null
        ? null
        : lessonTopic(meeting, await _db.subjectsDao.topics(subjectId));

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
          cards.add(
            LessonCard(
              id: c.id,
              title: c.title,
              content: c.content,
              summary: c.summary,
              pinned: pinnedFirst,
            ),
          );
        }
      }
    }

    return LessonMaterial(
      subjectName: subject?.name,
      courseLine: subject == null ? null : courseLine(subject, prefs),
      topicTitle: topic?.title,
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
    final meeting = await (_db.select(
      _db.meetings,
    )..where((t) => t.id.equals(meetingId))).getSingleOrNull();
    final subjectId = meeting?.subjectId;
    if (subjectId == null) return null;
    final subject = await _db.subjectsDao.subject(subjectId);
    if (subject == null) return null;
    final prefs = await _db.preferencesDao.current();
    final topic = lessonTopic(
      meeting!,
      await _db.subjectsDao.topics(subjectId),
    );

    final pinned = (await _db.subjectsDao.pinnedCardIds(meetingId)).toSet();
    final cards = await _db.subjectsDao.cards(subjectId);
    final chat = await _db.chatMessagesDao.messages(meetingId);
    final answerCards =
        await (_db.select(_db.answerCards)
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
    final segments = await _db.transcriptSegmentsDao.segmentsForMeeting(
      meetingId,
    );
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
      courseLine: courseLine(subject, prefs),
      topicTitle: topic?.title,
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
      important: [
        for (final m in ready)
          if (m.intent == ChatIntent.important)
            (note: m.body, excerpt: importantExcerpt(segments, m.atMs)),
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

  /// What transcription should know about the lesson: the subject, the words
  /// it uses ranked for what is being said right now, and the mishearings the
  /// student already fixed. Null when there is nothing to tell.
  Future<LessonListening?> listening(int meetingId) async {
    final meeting = await (_db.select(
      _db.meetings,
    )..where((t) => t.id.equals(meetingId))).getSingleOrNull();
    if (meeting == null) return null;
    final subjectId = meeting.subjectId;
    final subject = subjectId == null
        ? null
        : await _db.subjectsDao.subject(subjectId);
    final prefs = subject == null ? null : await _db.preferencesDao.current();
    final topics = subjectId == null
        ? const <SyllabusTopic>[]
        : await _db.subjectsDao.topics(subjectId);

    final terms = subject == null
        ? const <SubjectTerm>[]
        : await _db.subjectsDao.terms(subject.id);
    final cards = subject == null
        ? const <ContextCard>[]
        : await _db.subjectsDao.cards(subject.id);
    final pinned = (await _db.subjectsDao.pinnedCardIds(meetingId)).toSet();
    final chat = await _db.chatMessagesDao.messages(meetingId);
    final segments = await _db.transcriptSegmentsDao.segmentsForMeeting(
      meetingId,
    );

    final ready = [
      for (final m in chat)
        if (m.role == ChatRole.user &&
            m.status == ChatStatus.ready &&
            m.body.trim().isNotEmpty)
          m,
    ];
    final slideTexts = [
      for (final m in ready)
        if (m.intent == ChatIntent.photo) m.body.trim(),
    ];
    final contextMessages = [
      for (final m in ready)
        if (m.intent == ChatIntent.context) m.body.trim(),
    ];

    var lastEnd = 0;
    for (final s in segments) {
      if (s.endMs > lastEnd) lastEnd = s.endMs;
    }
    final recent = [
      for (final s in segments)
        if (s.endMs >= lastEnd - kListeningRecentMs &&
            (s.content ?? '').trim().isNotEmpty)
          s.content!.trim(),
    ].join(' ');

    // The topic the student picked, else the plan's topic for the lesson date.
    // While the lesson runs, what is being said may move it on — but only on
    // detectTopic's clear margin, and the move is written down so the chip and
    // the course overview agree with the prompt.
    var topic = lessonTopic(meeting, topics);
    if (meeting.topicId == null && topics.isNotEmpty) {
      final detected = detectTopic(topics, recent, current: topic);
      if (detected != null && detected.id != topic?.id) {
        topic = detected;
        await _db.subjectsDao.setMeetingTopic(meetingId, detected.id);
      }
    }

    VocabularyCard card(ContextCard c) =>
        (title: c.title, content: c.content, keywords: c.keywords);
    final pinnedCards = [
      for (final c in cards)
        if (pinned.contains(c.id)) c,
    ];
    final ranked = rankLessonTerms(
      topicTerms: [
        for (final t in (topic?.terms ?? '').split(','))
          if (t.trim().isNotEmpty) t.trim(),
      ],
      terms: [
        for (final t in terms)
          (
            id: t.id,
            term: t.term,
            heard: t.heard,
            source: t.source,
            uses: t.uses,
          ),
      ],
      pinnedCards: [for (final c in pinnedCards) card(c)],
      otherCards: [
        for (final c in cards)
          if (!pinned.contains(c.id)) card(c),
      ],
      photoTexts: slideTexts,
      contextMessages: contextMessages,
      recentTranscript: recent,
    );

    final corrections = <TermCorrection>[];
    final correctionIds = <int>[];
    for (final t in terms) {
      final heard = t.heard?.trim() ?? '';
      if (heard.isEmpty) continue;
      corrections.add((heard: heard, term: t.term));
      correctionIds.add(t.id);
    }

    final cardTitles = [for (final c in pinnedCards) c.title];
    final course = subject == null ? null : courseLine(subject, prefs);
    final listening = LessonListening(
      subjectName: subject?.name,
      courseLine: course,
      topicTitle: topic?.title,
      leadIn: lessonLeadIn(
        subjectName: subject?.name,
        courseLine: course,
        topicTitle: topic?.title,
        cardTitles: cardTitles,
        terms: ranked,
      ),
      corrections: corrections,
      correctionIds: correctionIds,
      terms: ranked,
      cardTitles: cardTitles,
      slideTexts: slideTexts,
      contextMessages: contextMessages,
    );
    return listening.isEmpty ? null : listening;
  }

  Future<void> markUsed(int cardId) =>
      _db.subjectsDao.markCardsUsed([cardId], DateTime.now());
}

/// What was said within [window] of a star at [atMs]: the live segments that
/// overlap it, in order. Live rather than refined, because refined windows are
/// minutes long and would bury the moment.
String importantExcerpt(
  List<TranscriptSegment> segments,
  int atMs, {
  int window = 30000,
}) {
  final from = atMs - window;
  final to = atMs + window;
  return [
    for (final s in segments)
      if (s.endMs > from &&
          s.startMs < to &&
          (s.content ?? '').trim().isNotEmpty)
        s.content!.trim(),
  ].join(' ');
}
