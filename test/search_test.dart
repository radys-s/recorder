import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/search.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/db/tables/refined_segments_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/data/search_service.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('searchWords', () {
    test('folds the query the way the notes library already does', () {
      expect(searchWords('Síť  Směrování'), ['sit', 'smerovani']);
    });

    test('punctuation alone is not a query', () {
      expect(searchWords('  ?? '), isEmpty);
    });
  });

  group('matchesWords', () {
    test('every word has to be there, in any order', () {
      expect(
        matchesWords('Směrovací tabulka v síti', ['sit', 'tabulka']),
        isTrue,
      );
      expect(matchesWords('Směrovací tabulka', ['sit', 'tabulka']), isFalse);
    });

    test('an empty query matches nothing, rather than everything', () {
      expect(matchesWords('cokoliv', const []), isFalse);
    });
  });

  group('excerptAround', () {
    test('cuts around the hit and marks it in the original text', () {
      final source =
          'Na úplném začátku hodiny jsme si po delším úvodu nejdřív '
          'zopakovali minulou látku a teprve pak si řekli, co je '
          'směrovací tabulka, '
          'a pak jsme počítali masky podsítí až do konce hodiny.';
      final excerpt = excerptAround(source, ['smerovaci']);
      final marked = excerpt.text.substring(
        excerpt.start,
        excerpt.start + excerpt.length,
      );
      // The diacritics come back, because the offsets point into the text the
      // student actually has in front of them.
      expect(marked, 'směrovací');
      expect(excerpt.text.startsWith('…'), isTrue);
      expect(excerpt.text.endsWith('…'), isTrue);
    });

    test(
      'a short text is shown whole and unmarked when only the title hit',
      () {
        final excerpt = excerptAround('Krátká poznámka', ['cestina']);
        expect(excerpt.text, 'Krátká poznámka');
        expect(excerpt.length, 0);
      },
    );

    test('newlines do not survive into a one-line excerpt', () {
      final excerpt = excerptAround('první řádek\n\ndruhý řádek', ['druhy']);
      expect(excerpt.text.contains('\n'), isFalse);
    });
  });

  group('SearchService', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> seedMeeting(String title, {int? subjectId}) =>
        db.meetingsDao.insertMeeting(
          MeetingsCompanion.insert(
            title: title,
            createdAt: DateTime(2026, 9, 18, 9),
            subjectId: Value(subjectId),
          ),
        );

    Future<void> seedSegment(
      int meetingId, {
      required int sequence,
      required String content,
      int startMs = 0,
      int endMs = 20000,
    }) async {
      await db
          .into(db.transcriptSegments)
          .insert(
            TranscriptSegmentsCompanion.insert(
              meetingId: meetingId,
              sequence: sequence,
              startMs: startMs,
              endMs: endMs,
              status: SegmentStatus.transcribed,
              localAudioPath: 'recordings/meeting_$meetingId/$sequence.wav',
              createdAt: DateTime(2026, 9, 18, 9),
              content: Value(content),
            ),
          );
    }

    test('finds a lesson by its subject, not only by its title', () async {
      final subject = await db.savedNotesDao.createFolder('Čeština');
      await seedMeeting('Hodina 1', subjectId: subject);
      await seedMeeting('Hodina 2');

      final hits = await SearchService(db).search('cestina');
      expect(hits.map((h) => h.title), ['Hodina 1']);
      expect(hits.single.subtitle, 'Čeština');
    });

    test('searches the transcript regardless of diacritics', () async {
      final id = await seedMeeting('Sítě');
      await seedSegment(
        id,
        sequence: 0,
        content: 'Dneska probereme směrování.',
      );

      final hits = await SearchService(db).search('SMEROVANI');
      final hit = hits.singleWhere((h) => h.kind == SearchKind.transcript);
      expect(hit.meetingId, id);
      expect(hit.segmentId, isNotNull);
    });

    test('a refined window wins over the live chunks it covers', () async {
      final id = await seedMeeting('Sítě');
      await seedSegment(
        id,
        sequence: 0,
        content: 'vylan je virtuální síť',
        startMs: 0,
        endMs: 30000,
      );
      await db
          .into(db.refinedSegments)
          .insert(
            RefinedSegmentsCompanion.insert(
              meetingId: id,
              windowIndex: 0,
              startMs: 0,
              endMs: 60000,
              engine: RefinedEngine.gemini,
              status: RefinedStatus.ready,
              createdAt: DateTime(2026, 9, 18, 9),
              content: const Value('VLAN je virtuální síť'),
            ),
          );

      final hits = await SearchService(db).search('virtualni');
      final transcript = hits.where((h) => h.kind == SearchKind.transcript);
      // One hit, from the better text — the live chunk under the window is not
      // a second result for the same sentence.
      expect(transcript.length, 1);
      expect(transcript.single.segmentId, isNull);
    });

    test('notes, cards and chat each land in their own group', () async {
      final subject = await db.savedNotesDao.createFolder('Dějepis');
      final meeting = await seedMeeting('Hodina', subjectId: subject);
      await db.savedNotesDao.saveNote(
        title: 'Výpisky',
        content: 'Husitství začalo roku 1419.',
        folderId: subject,
      );
      await db.subjectsDao.createCard(
        subjectId: subject,
        title: 'Husitství',
        content: 'Reformní hnutí v Čechách.',
      );
      await db.chatMessagesDao.addUserMessage(
        meetingId: meeting,
        text: 'Kdo vedl husitství?',
        intent: ChatIntent.question,
        atMs: 1000,
      );

      final kinds = (await SearchService(db).search('husitstvi'))
          .map((h) => h.kind)
          .toSet();
      expect(kinds, {SearchKind.note, SearchKind.card, SearchKind.chat});
    });

    test('a talkative lesson cannot fill the whole transcript group', () async {
      final id = await seedMeeting('Sítě');
      for (var i = 0; i < 8; i++) {
        await seedSegment(
          id,
          sequence: i,
          content: 'Znovu o směrování, kolo $i.',
          startMs: i * 20000,
          endMs: (i + 1) * 20000,
        );
      }

      final hits = await SearchService(db).search('smerovani');
      expect(hits.where((h) => h.kind == SearchKind.transcript).length, 3);
    });

    test('a blank query asks nothing of the database', () async {
      await seedMeeting('Hodina');
      expect(await SearchService(db).search('   '), isEmpty);
    });
  });

  group('recent searches', () {
    test('newest first, tidied, duplicates folded together', () {
      var recent = pushRecentSearch(const [], '  Síť   směrování ');
      recent = pushRecentSearch(recent, 'VLAN');
      recent = pushRecentSearch(recent, 'sit smerovani');
      expect(recent, ['sit smerovani', 'VLAN']);
    });

    test('punctuation alone is not remembered', () {
      expect(pushRecentSearch(const ['a'], ' ?? '), ['a']);
    });

    test('keeps only the last few', () {
      var recent = const <String>[];
      for (var i = 0; i < kMaxRecentSearches + 3; i++) {
        recent = pushRecentSearch(recent, 'dotaz $i');
      }
      expect(recent, hasLength(kMaxRecentSearches));
      expect(recent.first, 'dotaz ${kMaxRecentSearches + 2}');
    });

    test('a damaged stored value reads as no history', () {
      expect(decodeRecentSearches(null), isEmpty);
      expect(decodeRecentSearches('{nope'), isEmpty);
      expect(decodeRecentSearches('{"a":1}'), isEmpty);
      expect(decodeRecentSearches('["a", 3, "b"]'), ['a', 'b']);
    });
  });

  test('visibleHits hides what is waiting out its undo window', () {
    const excerpt = SearchExcerpt.plain('');
    const hits = [
      SearchHit(
        kind: SearchKind.lesson,
        title: 'a',
        excerpt: excerpt,
        meetingId: 1,
      ),
      SearchHit(
        kind: SearchKind.transcript,
        title: 'b',
        excerpt: excerpt,
        meetingId: 2,
      ),
      SearchHit(kind: SearchKind.note, title: 'c', excerpt: excerpt, noteId: 5),
      SearchHit(kind: SearchKind.card, title: 'd', excerpt: excerpt, cardId: 7),
    ];
    final left = visibleHits(
      hits,
      hiddenMeetings: {2},
      hiddenNotes: {5},
      hiddenCards: {8},
    );
    expect([for (final h in left) h.title], ['a', 'd']);
  });
}
