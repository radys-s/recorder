
import '../data/db/app_database.dart';
import '../data/db/tables/chat_messages_table.dart';
import '../stt/glossary.dart';
import 'context_builder.dart';

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
