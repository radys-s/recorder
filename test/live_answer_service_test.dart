import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/answer_source.dart';
import 'package:recorder/ai/context_builder.dart';
import 'package:recorder/ai/lesson_context_source.dart';
import 'package:recorder/ai/live_answer_service.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/web_answer_service.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/answer_cards_dao.dart';
import 'package:recorder/data/db/daos/preferences_dao.dart';
import 'package:recorder/data/db/daos/transcript_segments_dao.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';

class _Prefs implements PreferencesDao {
  _Prefs({required this.live, required this.web});
  final bool live;
  final bool web;

  @override
  Future<Preference> current() async => Preference(
    id: 0,
    transcriptLanguage: TranscriptLanguage.czech,
    notesDepth: NotesDepth.standard,
    liveAnswersEnabled: live,
    webAnswersEnabled: web,
    micSensitivity: MicSensitivity.medium,
    onboardingDismissed: false,
    contextCorrection: true,
    audioRetention: AudioRetention.sevenDays,
    lessonReminder: LessonReminder.off,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Segments implements TranscriptSegmentsDao {
  _Segments(this.segments);
  final List<TranscriptSegment> segments;

  @override
  Future<List<TranscriptSegment>> segmentsForMeeting(int meetingId) async => [
    for (final s in segments)
      if (s.meetingId == meetingId) s,
  ];

  @override
  Future<String?> previousTranscript(int meetingId, int sequence) async {
    final earlier = [
      for (final s in segments)
        if (s.meetingId == meetingId &&
            s.sequence < sequence &&
            s.content != null)
          s,
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));
    return earlier.isEmpty ? null : earlier.last.content;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cards implements AnswerCardsDao {
  final inserted = <AnswerCardsCompanion>[];

  @override
  Future<int> insertCard(AnswerCardsCompanion entry) async {
    inserted.add(entry);
    return inserted.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Web implements WebAnswerService {
  _Web(this.result);
  final WebAnswer? result;
  final questions = <String>[];

  @override
  Future<WebAnswer?> lookUp(String question) async {
    questions.add(question);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Lesson implements LessonContextSource {
  _Lesson(this.material);
  final LessonMaterial material;
  final used = <int>[];

  @override
  Future<LessonMaterial> load(int meetingId) async => material;

  @override
  Future<void> markUsed(int cardId) async => used.add(cardId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BrokenLesson extends _Lesson {
  _BrokenLesson() : super(const LessonMaterial());

  @override
  Future<LessonMaterial> load(int meetingId) async => throw StateError('db');
}

const _czechLesson = LessonMaterial(
  subjectName: 'Čeština',
  cards: [
    LessonCard(
      id: 41,
      title: 'Babička',
      content: 'Povídka Boženy Němcové.',
      summary: 'Obrazy venkovského života.',
      pinned: true,
    ),
  ],
);

/// Returns [reply] for every call, or throws it when it is an exception.
class _Llm extends LlmProvider {
  _Llm(this.reply);
  final Object reply;
  final calls = <List<LlmMessage>>[];
  final models = <String>[];
  final jsonModes = <bool>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    calls.add(messages);
    models.add(model);
    jsonModes.add(jsonMode);
    if (reply is Exception) throw reply;
    return LlmCompletion(content: reply as String);
  }
}

const _budget = 'Rozpočet na projekt jsou dva miliony korun.';
const _spent = 'Zatím jsme vyčerpali zhruba čtyřicet procent.';
const _question = 'Kolik nám tedy ještě zbývá v rozpočtu?';

TranscriptSegment _seg(
  int sequence,
  String? content, {
  int durationMs = 8000,
}) => TranscriptSegment(
  id: 100 + sequence,
  meetingId: 7,
  sequence: sequence,
  startMs: sequence * 20000,
  endMs: sequence * 20000 + durationMs,
  content: content,
  status: SegmentStatus.transcribed,
  localAudioPath: 'recordings/meeting_7/chunk_$sequence.wav',
  createdAt: DateTime(2026, 9, 14, 9, sequence),
);

/// The model's verdict on [_question], adjustable field by field.
String _verdict({
  Map<String, Object?> set = const {},
  List<String> omit = const [],
}) {
  final map =
      <String, Object?>{
          'is_question': true,
          'on_topic': true,
          'quote': 'Kolik nám tedy ještě zbývá v rozpočtu',
          'question': 'Kolik nám ještě zbývá v rozpočtu?',
          'answer': 'Zbývá zhruba 1,2 milionu korun.',
          'basis': 'meeting',
          'confidence': 0.9,
        }
        ..addAll(set)
        ..removeWhere((key, _) => omit.contains(key));
  return jsonEncode(map);
}

class _World {
  _World({
    required Object reply,
    List<TranscriptSegment>? segments,
    bool live = true,
    bool web = false,
    WebAnswer? webResult,
    this.lesson,
    Object? geminiReply,
    bool geminiKey = false,
  }) : llm = _Llm(reply),
       gemini = geminiReply == null ? null : _Llm(geminiReply),
       segments =
           segments ?? [_seg(0, _budget), _seg(1, _spent), _seg(2, _question)],
       webService = _Web(webResult) {
    service = LiveAnswerService(
      llm,
      _Segments(this.segments),
      cards,
      _Prefs(live: live, web: web),
      webService,
      lessonContext: lesson,
      gemini: gemini,
      hasGeminiKey: () async => geminiKey,
      pollInterval: const Duration(milliseconds: 1),
    );
  }

  final _Llm? gemini;

  final _Lesson? lesson;

  final _Llm llm;
  final List<TranscriptSegment> segments;
  final _Web webService;
  final cards = _Cards();
  late final LiveAnswerService service;

  /// Handles the segment with [sequence], as the queue worker would.
  Future<void> handle(int sequence) {
    final segment = segments.firstWhere((s) => s.sequence == sequence);
    return service.handleSegment(segment, segment.content!);
  }

  String get userMessage => llm.calls.single.last.content;
}

void main() {
  group('Gemini routing', () {
    TranscriptSegment long(int sequence, String content) =>
        _seg(sequence, content);

    test(
      'a lesson with a key is answered by Gemini with a wider look',
      () async {
        // Earlier lesson far longer than Groq's tail share (≈2 100 chars).
        final early =
            'ZAČÁTEK hodiny. ${'Mluvíme o realismu a venkově. ' * 150}';
        final world = _World(
          reply: _verdict(),
          geminiReply: _verdict(set: {'short': 'Asi 1,2 milionu.'}),
          geminiKey: true,
          lesson: _Lesson(_czechLesson),
          segments: [long(0, early), _seg(1, _spent), _seg(2, _question)],
        );
        await world.handle(2);

        expect(world.llm.calls, isEmpty);
        expect(world.gemini!.models.single, kGeminiModel);
        expect(world.gemini!.jsonModes.single, isTrue);
        expect(world.gemini!.calls.single.last.content, contains('ZAČÁTEK'));
        expect(world.cards.inserted.single.answer.value, 'Asi 1,2 milionu.');
      },
    );

    test('Gemini failing (429) falls back to Groq', () async {
      final world = _World(
        reply: _verdict(),
        geminiReply: const AiTransientException('limit', statusCode: 429),
        geminiKey: true,
        lesson: _Lesson(_czechLesson),
      );
      await world.handle(2);

      expect(world.gemini!.calls, hasLength(1));
      expect(world.llm.models.single, kGroqAnswerModel);
      expect(world.cards.inserted, hasLength(1));
    });

    test('without a key the lesson stays on Groq', () async {
      final world = _World(
        reply: _verdict(),
        geminiReply: _verdict(),
        lesson: _Lesson(_czechLesson),
      );
      await world.handle(2);
      expect(world.gemini!.calls, isEmpty);
      expect(world.llm.calls, hasLength(1));
    });

    test('a meeting without a subject stays on Groq even with a key', () async {
      final world = _World(
        reply: _verdict(),
        geminiReply: _verdict(),
        geminiKey: true,
      );
      await world.handle(2);
      expect(world.gemini!.calls, isEmpty);
      expect(world.llm.calls, hasLength(1));
    });

    test('the Gemini budget is wider than the automatic one', () {
      expect(
        ContextBudget.geminiLive.total,
        greaterThan(ContextBudget.automatic.total * 3),
      );
    });
  });

  group('in a lesson', () {
    test('an answer from a card names the card and skips the web', () async {
      final world = _World(
        reply: _verdict(
          set: {
            'basis': 'card',
            'card': '„Babička"',
            'short': 'Asi 1,2 milionu.',
            'detail': 'Dva miliony minus čtyřicet procent.',
          },
        ),
        web: true,
        lesson: _Lesson(_czechLesson),
      );
      await world.handle(2);

      final card = world.cards.inserted.single;
      expect(card.basis.value, 'card');
      expect(card.cardId.value, 41);
      expect(card.answer.value, 'Asi 1,2 milionu.');
      expect(card.detail.value, 'Dva miliony minus čtyřicet procent.');
      expect(world.webService.questions, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(world.lesson!.used, [41]);

      final sent = world.llm.calls.single;
      expect(sent.first.content, contains('Class mode'));
      expect(sent.last.content, contains('[Babička]'));
    });

    test('a card the model was never shown becomes knowledge', () async {
      final world = _World(
        reply: _verdict(set: {'basis': 'card', 'card': 'Máj'}),
        lesson: _Lesson(_czechLesson),
      );
      await world.handle(2);
      final card = world.cards.inserted.single;
      expect(card.basis.value, 'knowledge');
      expect(card.cardId.value, isNull);
    });

    test('classroom chatter the model marks off topic gets no card', () async {
      final world = _World(
        reply: _verdict(set: {'on_topic': false, 'answer': ''}),
        lesson: _Lesson(_czechLesson),
      );
      await world.handle(2);
      expect(world.cards.inserted, isEmpty);
    });

    test('broken lesson material falls back to the meeting prompt', () async {
      final world = _World(reply: _verdict(), lesson: _BrokenLesson());
      await world.handle(2);
      expect(world.cards.inserted, hasLength(1));
      expect(
        world.llm.calls.single.first.content,
        isNot(contains('Class mode')),
      );
    });
  });

  group('answer now', () {
    test('answers the end of the lesson on the last segment', () async {
      final world = _World(
        reply: _verdict(set: {'on_topic': false}),
        live: false,
      );
      final outcome = await world.service.answerNow(7);
      expect(outcome, AnswerNowOutcome.answered);
      // No on-topic veto, no live switch: the student asked.
      expect(world.cards.inserted.single.segmentId.value, 102);
      expect(world.userMessage, contains('answer now'));
    });

    test('says so when there is no question or nothing was heard', () async {
      final none = _World(reply: _verdict(set: {'is_question': false}));
      expect(await none.service.answerNow(7), AnswerNowOutcome.noQuestion);
      expect(none.cards.inserted, isEmpty);

      final silent = _World(reply: _verdict(), segments: [_seg(0, null)]);
      expect(await silent.service.answerNow(7), AnswerNowOutcome.nothingHeard);
      expect(silent.llm.calls, isEmpty);
    });

    test('gives up waiting for a chunk that never comes back', () async {
      final pending = TranscriptSegment(
        id: 199,
        meetingId: 7,
        sequence: 3,
        startMs: 60000,
        endMs: 64000,
        status: SegmentStatus.uploading,
        localAudioPath: 'x.wav',
        createdAt: DateTime(2026, 9, 14),
      );
      final world = _World(
        reply: _verdict(),
        segments: [
          _seg(0, _budget),
          _seg(1, _spent),
          _seg(2, _question),
          pending,
        ],
      );
      final outcome = await world.service.answerNow(
        7,
        maxWait: const Duration(milliseconds: 20),
      );
      expect(outcome, AnswerNowOutcome.answered);
      expect(world.cards.inserted.single.segmentId.value, 102);
    });
  });

  test('with live answers off, nothing is sent', () async {
    final world = _World(reply: _verdict(), live: false);
    await world.handle(2);
    expect(world.llm.calls, isEmpty);
    expect(world.cards.inserted, isEmpty);
  });

  test('a plain statement never reaches the model', () async {
    final world = _World(
      reply: _verdict(),
      segments: [
        _seg(0, _budget),
        _seg(1, 'Karel připraví přehled výdajů do pátku.', durationMs: 20000),
      ],
    );
    await world.handle(1);
    expect(world.llm.calls, isEmpty);
  });

  test(
    'a grounded question becomes a card with the meeting as its basis',
    () async {
      final world = _World(reply: _verdict());
      await world.handle(2);

      final card = world.cards.inserted.single;
      expect(card.meetingId.value, 7);
      expect(card.segmentId.value, 102);
      expect(card.question.value, 'Kolik nám ještě zbývá v rozpočtu?');
      expect(card.answer.value, 'Zbývá zhruba 1,2 milionu korun.');
      expect(card.basis.value, 'meeting');
      expect(card.sources.value, isNull);
      expect(card.dismissed.value, isFalse);

      expect(world.llm.models.single, kGroqAnswerModel);
      expect(world.llm.jsonModes.single, isTrue);
      expect(world.webService.questions, isEmpty);
    },
  );

  test(
    'the newest passage is sent once, after the context, with the pause',
    () async {
      final world = _World(reply: _verdict());
      await world.handle(2);

      final message = world.userMessage;
      expect(
        message,
        startsWith(
          'Meeting so far:\n$_budget $_spent\n\nNewest passage:\n'
          '$_question',
        ),
      );
      expect(
        message.split(_question),
        hasLength(2),
        reason: 'the question must not be in the context as well',
      );
      expect(
        message,
        endsWith('The room went quiet right after this passage.'),
      );
    },
  );

  test('a chunk that ran to the cap carries no pause note', () async {
    final world = _World(
      reply: _verdict(),
      segments: [
        _seg(0, _budget),
        _seg(1, _spent),
        _seg(2, _question, durationMs: 20000),
      ],
    );
    await world.handle(2);
    expect(world.userMessage, isNot(contains('went quiet')));
  });

  group('verdicts that leave no card', () {
    final replies = <String, String>{
      'not a question': _verdict(set: {'is_question': false}),
      'off topic': _verdict(set: {'on_topic': false}),
      'no answer': _verdict(set: {'answer': '   '}),
      'low confidence': _verdict(set: {'confidence': 0.3}),
      'unreadable confidence': _verdict(set: {'confidence': 'hodně'}),
      'no wording at all': _verdict(set: {'quote': '', 'question': ''}),
      'a quote nobody said': _verdict(
        set: {
          'quote': 'Kdo podepíše smlouvu s dodavatelem',
          'question': 'Kdo podepíše smlouvu s dodavatelem?',
        },
      ),
      'a question nobody asked under a real quote': _verdict(
        set: {'question': 'Kdo podepíše smlouvu s dodavatelem a kdy?'},
      ),
      'not JSON': 'Ano, to je otázka.',
    };
    replies.forEach((name, reply) {
      test(name, () async {
        final world = _World(reply: reply);
        await world.handle(2);
        expect(world.llm.calls, hasLength(1));
        expect(world.cards.inserted, isEmpty);
      });
    });
  });

  test('lenient types still produce a card', () async {
    for (final reply in [
      _verdict(set: {'is_question': 'true', 'confidence': '85'}),
      _verdict(set: {'is_question': 1, 'confidence': '0,8'}),
      _verdict(omit: ['on_topic']),
    ]) {
      final world = _World(reply: reply);
      await world.handle(2);
      expect(world.cards.inserted, hasLength(1), reason: reply);
    }
  });

  test(
    'an unknown basis is shown as the meeting and never goes to the web',
    () async {
      final world = _World(
        reply: _verdict(set: {'basis': 'internet'}),
        web: true,
        webResult: WebAnswer(answer: 'x', sources: const []),
      );
      await world.handle(2);
      expect(world.cards.inserted.single.basis.value, 'meeting');
      expect(world.webService.questions, isEmpty);
    },
  );

  test('a question that lives only in the previous segment is not answered '
      'again', () async {
    final world = _World(
      reply: _verdict(),
      segments: [
        _seg(0, _budget),
        _seg(1, _spent),
        _seg(2, _question),
        _seg(3, 'Jasně, a co dál?'),
      ],
    );
    await world.handle(3);
    expect(world.cards.inserted, isEmpty);
  });

  group('a quote too short to vouch for anything', () {
    test('cannot carry a question invented around it', () async {
      final world = _World(
        reply: _verdict(
          set: {
            'quote': 'A kolik',
            'question': 'Kolik stojí roční licence Microsoft Teams?',
            'basis': 'knowledge',
          },
        ),
        segments: [_seg(0, _budget), _seg(1, _spent), _seg(2, 'A kolik?')],
      );
      await world.handle(2);
      expect(world.cards.inserted, isEmpty);
    });

    test('but may borrow the subject the meeting just named', () async {
      final world = _World(
        reply: _verdict(
          set: {
            'quote': 'A kolik',
            'question': 'Kolik stojí licence Microsoft Teams?',
            'basis': 'knowledge',
          },
        ),
        segments: [
          _seg(0, 'Budeme potřebovat licence Microsoft Teams pro celý tým.'),
          _seg(1, 'Cenu jsem ještě nezjišťoval.'),
          _seg(2, 'A kolik?'),
        ],
      );
      await world.handle(2);
      expect(
        world.cards.inserted.single.question.value,
        'Kolik stojí licence Microsoft Teams?',
      );
    });
  });

  group('the web hop', () {
    const rateQuestion = 'Jaká je teď základní sazba ČNB?';
    final rateSegments = [
      _seg(0, _budget),
      _seg(1, 'Úvěr bychom brali na pět let.'),
      _seg(2, 'A jaká je teď základní sazba ČNB?'),
    ];
    String rateVerdict({String basis = 'knowledge'}) => _verdict(
      set: {
        'quote': 'A jaká je teď základní sazba ČNB',
        'question': rateQuestion,
        'answer': 'Naposledy se pohybovala kolem 3,5 %.',
        'basis': basis,
      },
    );
    final found = WebAnswer(
      answer: 'Základní sazba ČNB je 3,5 %.',
      sources: [
        AnswerSource(title: 'ČNB', url: Uri.parse('https://www.cnb.cz/sazby')),
      ],
    );

    test(
      'replaces an answer from knowledge, sending only the question',
      () async {
        final world = _World(
          reply: rateVerdict(),
          segments: rateSegments,
          web: true,
          webResult: found,
        );
        await world.handle(2);

        expect(world.webService.questions, [rateQuestion]);
        final card = world.cards.inserted.single;
        expect(card.basis.value, 'web');
        expect(card.answer.value, 'Základní sazba ČNB je 3,5 %.');
        expect(card.sources.value, encodeAnswerSources(found.sources));
      },
    );

    test('never overrides the meeting', () async {
      final world = _World(reply: _verdict(), web: true, webResult: found);
      await world.handle(2);
      expect(world.webService.questions, isEmpty);
      expect(world.cards.inserted.single.basis.value, 'meeting');
    });

    test('keeps the first answer when the web gives nothing', () async {
      final world = _World(
        reply: rateVerdict(),
        segments: rateSegments,
        web: true,
        webResult: null,
      );
      await world.handle(2);
      final card = world.cards.inserted.single;
      expect(card.basis.value, 'knowledge');
      expect(card.answer.value, 'Naposledy se pohybovala kolem 3,5 %.');
      expect(card.sources.value, isNull);
    });

    test('stays off while the switch is off', () async {
      final world = _World(
        reply: rateVerdict(basis: 'unknown'),
        segments: rateSegments,
        webResult: found,
      );
      await world.handle(2);
      expect(world.webService.questions, isEmpty);
      expect(world.cards.inserted.single.basis.value, 'unknown');
    });
  });

  test('a failing model call is swallowed', () async {
    final world = _World(
      reply: const AiTransientException('bad gateway', statusCode: 503),
    );
    await expectLater(world.handle(2), completes);
    expect(world.cards.inserted, isEmpty);
  });

  test('the context is the tail of the meeting, capped', () async {
    final long = List.filled(500, 'slovo').join(' ');
    final world = _World(
      reply: _verdict(),
      segments: [
        _seg(0, long),
        _seg(1, null),
        _seg(2, '   '),
        _seg(3, 'KONEC.'),
        _seg(4, _question),
      ],
    );
    await world.handle(4);

    final message = world.userMessage;
    final context = message.substring(
      'Meeting so far:\n'.length,
      message.indexOf('\n\nNewest passage:'),
    );
    expect(context, hasLength(kAnswerContextChars));
    expect(context, endsWith('slovo KONEC.'));
  });
}
