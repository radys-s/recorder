import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/lesson_context_source.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/syllabus.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';
import 'package:recorder/data/db/tables/subject_terms_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/stt/lesson_vocabulary.dart';
import 'package:recorder/stt/refined_transcriber.dart';
import 'package:recorder/stt/transcript_corrector.dart';
import 'package:recorder/stt/transcript_sanitizer.dart';
import 'package:recorder/stt/whisper_segment_filter.dart';

VocabularyTerm _term(
  int id,
  String term, {
  String? heard,
  TermSource source = TermSource.card,
  int uses = 0,
}) => (id: id, term: term, heard: heard, source: source, uses: uses);

void main() {
  group('rankLessonTerms', () {
    test('taught words first, then pinned cards, then the rest', () {
      final ranked = rankLessonTerms(
        terms: [
          _term(1, 'Realismus'),
          _term(2, 'Proško', heard: 'prosko', source: TermSource.correction),
          _term(3, 'Viktorka', source: TermSource.manual, uses: 5),
        ],
        pinnedCards: [
          (
            title: 'Babička',
            content: 'Píše Božena Němcová.',
            keywords: 'Barunka',
          ),
        ],
        otherCards: [
          (title: 'Máj', content: '', keywords: 'Karel Hynek Mácha'),
        ],
        photoTexts: ['Na tabuli jsou Ratibořice'],
      );
      final words = [for (final t in ranked) t.term];
      expect(words.take(4), ['Viktorka', 'Proško', 'Barunka', 'Babička']);
      expect(words, containsAll(['Božena', 'Němcová', 'Realismus', 'Máj']));
      expect(words.last, 'Ratibořice');
      expect(ranked.firstWhere((t) => t.term == 'Proško').id, 2);
    });

    test('topic terms rank right after the taught ones', () {
      final ranked = rankLessonTerms(
        terms: [
          _term(1, 'Proško', source: TermSource.correction),
          _term(2, 'Realismus'),
        ],
        topicTerms: ['OSPF', 'RIP'],
        pinnedCards: [(title: 'Babička', content: '', keywords: 'Barunka')],
      );
      expect(
        [for (final t in ranked.take(3)) t.term],
        ['Proško', 'OSPF', 'RIP'],
      );
    });

    test('the rest is ordered by what was just said', () {
      final ranked = rankLessonTerms(
        terms: [_term(1, 'Fotosyntéza'), _term(2, 'Revoluce')],
        recentTranscript: 'Francouzská revoluce začala roku 1789.',
      );
      expect(ranked.first.term, 'Revoluce');
    });

    test('duplicates differing only in case and diacritics are dropped', () {
      final ranked = rankLessonTerms(
        terms: [
          _term(1, 'Proško', source: TermSource.manual),
          _term(2, 'prosko'),
        ],
      );
      expect(ranked, hasLength(1));
    });
  });

  group('lessonLeadIn', () {
    test('reads like a sentence and stays under the limit', () {
      final lead = lessonLeadIn(
        subjectName: 'Čeština',
        cardTitles: ['Babička'],
        terms: [for (var i = 0; i < 80; i++) (term: 'Pojem$i', id: null)],
      )!;
      expect(lead, startsWith('Hodina: Čeština — Babička. Pojmy: Pojem0, '));
      expect(lead, endsWith('.'));
      expect(lead.length, lessThanOrEqualTo(kLessonLeadInMaxChars));
    });

    test('a title is not repeated among the terms', () {
      final lead = lessonLeadIn(
        subjectName: 'Čeština',
        cardTitles: ['Babička'],
        terms: [(term: 'babicka', id: null), (term: 'Viktorka', id: null)],
      );
      expect(lead, 'Hodina: Čeština — Babička. Pojmy: Viktorka.');
    });

    test('the course and the topic lead, still under the limit', () {
      final lead = lessonLeadIn(
        subjectName: 'Sítě',
        courseLine: 'Počítačové sítě, SOŠ, SPŠE Ječná, obor IT, 3. ročník',
        topicTitle: 'Směrování',
        cardTitles: ['VLAN'],
        terms: [for (var i = 0; i < 80; i++) (term: 'Pojem$i', id: null)],
      )!;
      expect(
        lead,
        startsWith(
          'Hodina: Počítačové sítě, SOŠ, SPŠE Ječná, obor IT, 3. ročník '
          '— téma: Směrování, VLAN. Pojmy: ',
        ),
      );
      expect(lead.length, lessThanOrEqualTo(kLessonLeadInMaxChars));
    });

    test('nothing to say is null', () {
      expect(lessonLeadIn(), isNull);
    });
  });

  test('termsMentioned matches whole words only', () {
    const terms = [
      (term: 'Proško', id: 1),
      (term: 'Máj', id: 2),
      (term: 'Karel Hynek', id: 3),
    ];
    expect(
      termsMentioned('Pak přišel prosko a Karel Hynek psal. Májka.', terms),
      {1, 3},
    );
  });

  group('keyTermsFromNotes', () {
    test('takes the term before the dash, only in its section', () {
      const notes = '''
Téma: Babička

**Klíčové pojmy:**
- Realismus – směr zobrazující skutečnost
- **Idyla**: klidný obraz venkova
- Tady je jen věta bez definice
Příklady:
- Viktorka – postava z knihy''';
      expect(keyTermsFromNotes(notes), ['Realismus', 'Idyla']);
    });

    test('a long sentence is not a term', () {
      expect(
        keyTermsFromNotes(
          'Klíčové pojmy:\n- Tohle je dlouhá věta o něčem úplně jiném – x',
        ),
        isEmpty,
      );
    });
  });

  group('acceptCorrection', () {
    test('accepts a spelling fix', () {
      expect(
        acceptCorrection(
          'A viktorko zpívala u vody.',
          'A Viktorka zpívala u vody.',
        ),
        isNull,
      );
    });

    test('rejects a rewrite', () {
      expect(
        acceptCorrection(
          'A viktorko zpívala u vody.',
          'Viktorka byla postava, která zpívala.',
        ),
        isNotNull,
      );
    });

    test('rejects added words', () {
      expect(
        acceptCorrection(
          'Pak přišel k mlýnu a sedl si na lavici.',
          'Pak přišel mladý myslivec k mlýnu a sedl si.',
        ),
        isNotNull,
      );
    });

    test('rejects a different word unless it is a known term', () {
      const raw = 'Autorem je pan Novák z Prahy.';
      const fixed = 'Autorem je pan Mácha z Prahy.';
      expect(acceptCorrection(raw, fixed), isNotNull);
      expect(acceptCorrection(raw, fixed, knownTerms: ['K. H. Mácha']), isNull);
    });
  });

  group('TranscriptCorrector.correctBatch', () {
    const lesson = LessonListening(
      subjectName: 'Počítačové sítě',
      courseLine: 'Počítačové sítě, SOŠ, obor IT, 3. ročník',
      topicTitle: 'Směrování',
      leadIn: '',
      terms: [(term: 'OSPF', id: 1), (term: 'VLAN', id: 2)],
    );
    const texts = [
      'Nastavíme vílan na obou směrovačích.',
      'Pak se podíváme na tabulku.',
    ];

    test('one request covers every chunk, judged one by one', () async {
      final llm = _BatchLlm(
        '{"texts": ["Nastavíme VLAN na obou směrovačích.", '
        '"Pak se podíváme na směrovací tabulku a na její obsah."]}',
      );
      final out = await TranscriptCorrector(llm)
          .correctBatch(texts: texts, lesson: lesson);

      expect(llm.prompts, hasLength(1));
      expect(out.first, 'Nastavíme VLAN na obou směrovačích.');
      // The second chunk grew a clause nobody said, and it is rejected on its
      // own without costing the first one its fix.
      expect(out.last, isNull);
    });

    test(
      'the course, the topic and the numbered chunks are all asked about',
      () async {
        final llm = _BatchLlm('{"texts": ["a", "b"]}');
        await TranscriptCorrector(llm)
            .correctBatch(texts: texts, lesson: lesson);

        final prompt = llm.prompts.single;
        expect(
          prompt,
          contains('Course: Počítačové sítě, SOŠ, obor IT, 3. ročník'),
        );
        expect(prompt, contains('Topic of this lesson: Směrování'));
        expect(prompt, contains('1) ${texts.first}'));
        expect(prompt, contains('2) ${texts.last}'));
      },
    );

    test('a reply that lost a chunk is thrown away whole', () async {
      // Anything but a one-to-one answer has lost track of which text is
      // which, and applying it would move words between segments.
      final llm = _BatchLlm(
        '{"texts": ["Nastavíme VLAN na obou směrovačích."]}',
      );
      expect(
        await TranscriptCorrector(llm)
            .correctBatch(texts: texts, lesson: lesson),
        [null, null],
      );
    });

    test('a failed call corrects nothing and never throws', () async {
      final llm = _BatchLlm(null);
      expect(
        await TranscriptCorrector(llm)
            .correctBatch(texts: texts, lesson: lesson),
        [null, null],
      );
    });
  });

  group('confidence', () {
    Map<String, Object> seg(
      String text,
      double logprob,
      double start,
      double end,
    ) => {
      'text': text,
      'no_speech_prob': 0.01,
      'avg_logprob': logprob,
      'compression_ratio': 1.2,
      'start': start,
      'end': end,
    };

    test('is the duration-weighted mean of the kept segments', () {
      final r = filterWhisperSegments([
        seg(' Dlouhá věta.', -0.2, 0, 9),
        seg(' Krátká.', -1.1, 9, 10),
      ])!;
      expect(r.confidence, closeTo(-0.29, 0.001));
    });

    test('thresholds at their boundaries', () {
      expect(isLowConfidence(null), isFalse);
      expect(isLowConfidence(-0.9), isFalse);
      expect(isLowConfidence(-0.91), isTrue);
      expect(isVeryLowConfidence(-1.3), isFalse);
      expect(isVeryLowConfidence(-1.31), isTrue);
    });
  });

  test('an echo of the lesson lead-in is caught', () {
    const lead =
        'Hodina: Čeština — Babička. Pojmy: Viktorka, Proško, realismus.';
    expect(isPromptEcho(lead, lead), isTrue);
    expect(isPromptEcho('Viktorka, Proško, realismus.', lead), isTrue);
    expect(isPromptEcho('Viktorka šla k vodě a zpívala.', lead), isFalse);
  });

  test('the refined request carries vocabulary, slides and notes', () {
    final user = refinedGeminiMessages(
      const RefinedContext(
        subjectName: 'Čeština',
        terms: ['Viktorka', 'Proško'],
        slideTexts: ['Realismus v české literatuře'],
        contextMessages: ['Čteme kapitolu o Viktorce'],
      ),
    ).last.content;
    expect(user, contains('Lesson vocabulary: Viktorka, Proško'));
    expect(user, contains('Text from the slides:\nRealismus'));
    expect(user, contains("Student's notes:\nČteme kapitolu"));
  });

  group('LessonContextSource.listening', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> lesson(int? subjectId, List<String> segments) async {
      final id = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Hodina',
          createdAt: DateTime(2026, 9, 17, 8),
          subjectId: Value(subjectId),
        ),
      );
      for (var i = 0; i < segments.length; i++) {
        await db.transcriptSegmentsDao.insertSegment(
          TranscriptSegmentsCompanion.insert(
            meetingId: id,
            sequence: i,
            startMs: i * 10000,
            endMs: (i + 1) * 10000,
            content: Value(segments[i]),
            status: SegmentStatus.transcribed,
            localAudioPath: 'x.wav',
            createdAt: DateTime(2026, 9, 17),
          ),
        );
      }
      return id;
    }

    test('gathers subject, pinned cards, corrections and slides', () async {
      final cz = await db.savedNotesDao.createFolder('Čeština');
      final babicka = await db.subjectsDao.createCard(
        subjectId: cz,
        title: 'Babička',
        content: 'Kniha od Boženy Němcové.',
      );
      await db.subjectsDao.createCard(subjectId: cz, title: 'Máj');
      final proskoId = await db.subjectsDao.addTerm(
        cz,
        'Proško',
        heard: 'prosko',
        source: TermSource.correction,
      );
      final id = await lesson(cz, ['Dnes čteme o Viktorce.']);
      await db.subjectsDao.pinCards(id, [babicka]);
      final photo = await db.chatMessagesDao.addPhotoMessage(
        meetingId: id,
        imagePath: 'p.jpg',
        atMs: 1000,
      );
      await db.chatMessagesDao.completePhoto(
        photo,
        text: 'Mapa: kde leží Ratibořice',
        description: 'Tabule',
      );
      await db.chatMessagesDao.addUserMessage(
        meetingId: id,
        text: 'Kapitola o Viktorce',
        intent: ChatIntent.context,
        atMs: 2000,
      );

      final l = (await LessonContextSource(db).listening(id))!;
      expect(l.subjectName, 'Čeština');
      expect(l.cardTitles, ['Babička']);
      expect(l.leadIn, startsWith('Hodina: Čeština — Babička. Pojmy: Proško'));
      expect(l.corrections, [(heard: 'prosko', term: 'Proško')]);
      expect(l.correctionIds, [proskoId]);
      expect(l.slideTexts, ['Mapa: kde leží Ratibořice']);
      expect(l.contextMessages, ['Kapitola o Viktorce']);
      expect([for (final t in l.terms) t.term], contains('Ratibořice'));
    });

    test('the course line and the plan topic reach the prompts', () async {
      final site = await db.savedNotesDao.createFolder('Sítě');
      await db.subjectsDao.setSubjectProfile(site, fullName: 'Počítačové sítě');
      await db.preferencesDao.setStudyProfile(
        schoolType: SchoolType.secondaryTechnical,
        studyField: 'IT',
        studyYear: 3,
      );
      await db.subjectsDao.replaceTopics(site, const [
        SyllabusTopicDraft(
          title: 'Směrování',
          terms: ['OSPF', 'RIP'],
          monthFrom: 9,
          monthTo: 9,
        ),
      ], SyllabusSource.pasted);
      final id = await lesson(site, ['Dnes budeme počítat masky.']);

      final l = (await LessonContextSource(db).listening(id))!;
      expect(l.courseLine, 'Počítačové sítě, SOŠ, obor IT, 3. ročník');
      expect(l.topicTitle, 'Směrování');
      expect(l.leadIn, contains('téma: Směrování'));
      expect([for (final t in l.terms.take(2)) t.term], ['OSPF', 'RIP']);

      final notes = (await LessonContextSource(db).notesInput(id))!;
      expect(notes.courseLine, 'Počítačové sítě, SOŠ, obor IT, 3. ročník');
      expect(notes.topicTitle, 'Směrování');
    });

    test(
      'a detected topic is written down, a picked one is left alone',
      () async {
        final site = await db.savedNotesDao.createFolder('Sítě');
        await db.subjectsDao.replaceTopics(site, const [
          SyllabusTopicDraft(title: 'Kabeláž', terms: ['kroucená dvojlinka']),
          SyllabusTopicDraft(title: 'Směrování', terms: ['OSPF', 'RIP']),
        ], SyllabusSource.pasted);
        final id = await lesson(site, [
          'Dneska OSPF a RIP, podíváme se na OSPF i na směrování.',
        ]);

        final l = (await LessonContextSource(db).listening(id))!;
        expect(l.topicTitle, 'Směrování');
        final topics = await db.subjectsDao.topics(site);
        final meeting = await db.meetingsDao.watchMeetingByIdOnce(id);
        expect(
          meeting!.topicId,
          topics.firstWhere((t) => t.title == 'Směrování').id,
        );

        // A hand-picked topic stays, whatever is being said.
        await db.subjectsDao.setMeetingTopic(
          id,
          topics.firstWhere((t) => t.title == 'Kabeláž').id,
        );
        final again = (await LessonContextSource(db).listening(id))!;
        expect(again.topicTitle, 'Kabeláž');
      },
    );

    test('a meeting with nothing to tell is null', () async {
      final id = await lesson(null, ['Ahoj.']);
      expect(await LessonContextSource(db).listening(id), isNull);
    });
  });
}

/// Answers the corrector with a fixed reply, or fails the call.
class _BatchLlm extends LlmProvider {
  _BatchLlm(this.reply);

  final String? reply;
  final prompts = <String>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    prompts.add(messages.last.content);
    final reply = this.reply;
    if (reply == null) throw const AiTransientException('rate limited');
    return LlmCompletion(content: reply);
  }
}
