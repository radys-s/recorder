import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/chat_answer_service.dart';
import 'package:recorder/ai/chat_intent.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/features/meeting_detail/timeline.dart';
import 'package:recorder/features/meeting_detail/widgets/answer_basis.dart';
import 'package:recorder/stt/glossary.dart';
import 'package:recorder/stt/groq_whisper_stt_provider.dart';

final _at = DateTime(2026, 9, 15);

TranscriptSegment _segment(int id, int startMs) => TranscriptSegment(
      id: id,
      meetingId: 1,
      sequence: id,
      startMs: startMs,
      endMs: startMs + 10000,
      content: 'segment $id',
      status: SegmentStatus.transcribed,
      localAudioPath: 'a.wav',
      createdAt: _at,
    );

AnswerCard _card(int id, int segmentId) => AnswerCard(
      id: id,
      meetingId: 1,
      segmentId: segmentId,
      question: 'Q',
      answer: 'A',
      basis: 'meeting',
      dismissed: false,
      createdAt: _at,
    );

ChatMessage _message(int id, int atMs,
        {ChatRole role = ChatRole.user, int? replyTo}) =>
    ChatMessage(
      id: id,
      meetingId: 1,
      role: role,
      intent: ChatIntent.question,
      body: 'm$id',
      atMs: atMs,
      status: ChatStatus.ready,
      replyTo: replyTo,
      createdAt: _at,
    );

void main() {
  group('detectChatIntent', () {
    test('rules, questions and context', () {
      expect(detectChatIntent('Odpovídej jednou větou'), ChatIntent.rule);
      expect(detectChatIntent('prosím piš stručně'), ChatIntent.rule);
      expect(detectChatIntent('Pravidlo: vždy uveď autora'), ChatIntent.rule);
      expect(detectChatIntent('Kdo byl Proško?'), ChatIntent.question);
      expect(detectChatIntent('jaký je to literární druh'), ChatIntent.question);
      expect(detectChatIntent('Čteme úryvek, kde Viktorka zpívá u splavu'),
          ChatIntent.context);
      expect(detectChatIntent('   '), ChatIntent.context);
    });

    test('the chip cycles through the three typed intents', () {
      expect(cycleChatIntent(ChatIntent.context), ChatIntent.question);
      expect(cycleChatIntent(ChatIntent.question), ChatIntent.rule);
      expect(cycleChatIntent(ChatIntent.rule), ChatIntent.context);
      expect(cycleChatIntent(ChatIntent.photo), ChatIntent.photo);
    });
  });

  group('buildWhisperGlossary', () {
    test('keywords, then titles, then names from inside sentences', () {
      final glossary = buildWhisperGlossary([
        (
          title: 'Babička',
          content: 'Na Starém bělidle žila babička. Potkala Viktorka Proška, '
              'pak Viktorka zpívala.',
          keywords: 'Barunka, Němcová',
        ),
      ]);
      // Viktorka is the most frequent name; sentence openers never count.
      expect(glossary, startsWith('Barunka, Němcová, Babička, Viktorka, '));
      expect(glossary, allOf(contains('Starém'), contains('Proška')));
      expect(glossary, isNot(contains('Potkala')));
    });

    test('dedupes without diacritics and respects the length', () {
      final glossary = buildWhisperGlossary([
        (title: 'Máj', content: '', keywords: 'Maj, Mácha, Jarmila, Vilém'),
      ], maxChars: 16);
      expect(glossary, 'Maj, Mácha');
      expect(glossary!.length, lessThanOrEqualTo(16));
      expect(buildWhisperGlossary([]), isNull);
    });
  });

  test('whisperPrompt puts the glossary before the tail', () {
    expect(
      GroqWhisperSttProvider.whisperPrompt(
          glossary: 'Proško, Viktorka', context: 'a pak přišla'),
      'Proško, Viktorka. a pak přišla',
    );
    expect(GroqWhisperSttProvider.whisperPrompt(glossary: ' ', context: null),
        isNull);
    final long = GroqWhisperSttProvider.whisperPrompt(context: 'x' * 5000)!;
    expect(long.length, lessThan(5000));
  });

  test('mergeTimeline places cards, messages and replies', () {
    final s1 = _segment(1, 0), s2 = _segment(2, 10000), s3 = _segment(3, 20000);
    final card = _card(10, 2), orphanCard = _card(11, 99);
    final question = _message(20, 12000);
    final reply = _message(21, 15000, role: ChatRole.assistant, replyTo: 20);
    final late = _message(22, 50000);
    final lostReply = _message(23, 1000, role: ChatRole.assistant, replyTo: 999);

    final items = mergeTimeline(
      [s1, s2, s3],
      [orphanCard, card],
      [late, reply, question, lostReply],
    );
    expect(items, [
      s1,
      lostReply,
      s2,
      card,
      question,
      reply,
      s3,
      late,
      orphanCard,
    ]);
  });

  group('parseChatReply', () {
    test('reads short, detail, basis and card', () {
      final r = parseChatReply(
          '{"short": "Novela", "detail": "Protože…", "basis": "card", "card": "Babička"}')!;
      expect(r.short, 'Novela');
      expect(r.detail, 'Protože…');
      expect(r.basis, 'card');
      expect(r.card, 'Babička');
    });

    test('falls back sensibly on a sloppy reply', () {
      expect(parseChatReply('{"answer": "Mácha", "basis": "weird"}')!.basis,
          'knowledge');
      final promoted = parseChatReply('{"detail": "Jen detail."}')!;
      expect(promoted.short, 'Jen detail.');
      expect(promoted.detail, isEmpty);
      expect(parseChatReply('{"short": "A", "detail": "A"}')!.detail, isEmpty);
      expect(parseChatReply('{"short": ""}'), isNull);
      expect(parseChatReply('not json'), isNull);
    });
  });

  test('answerBasisBadge names the card', () {
    expect(answerBasisBadge('card', cardTitle: 'Máj')!.label, 'Z karty „Máj"');
    expect(answerBasisBadge('card:Babička')!.label, 'Z karty „Babička"');
    expect(answerBasisBadge('card')!.label, 'Z karty');
    expect(answerBasisBadge('meeting'), isNull);
  });
}
