import '../core/search.dart';
import 'db/app_database.dart';

/// Searches everything the app has written: lessons, transcripts, notes, cards
/// and the chat typed during a lesson.
///
/// One-shot reads, not streams. A search is a question asked once, and a
/// stream per table would keep the whole corpus subscribed for as long as the
/// screen is open — the lesson M26 taught with `Stream.first`.
class SearchService {
  SearchService(this._db);

  final AppDatabase _db;

  /// At most this many hits per kind, and per lesson within the transcripts,
  /// so one talkative lesson cannot bury every other result.
  static const _perKind = 25;
  static const _perMeeting = 3;

  Future<List<SearchHit>> search(String query) async {
    final words = searchWords(query);
    if (words.isEmpty) return const [];

    final subjects = {
      for (final s in await _db.subjectsDao.allSubjects())
        s.subject.id: s.subject.name,
    };
    final meetings = await _db.meetingsDao.allMeetingsOnce();
    final byId = {for (final m in meetings) m.id: m};

    final hits = <SearchHit>[
      ..._lessons(meetings, subjects, words),
      ...await _transcripts(byId, subjects, words),
      ...await _notes(subjects, words),
      ...await _cards(subjects, words),
      ...await _chat(byId, subjects, words),
    ];
    return hits;
  }

  Iterable<SearchHit> _lessons(
    List<Meeting> meetings,
    Map<int, String> subjects,
    List<String> words,
  ) {
    final hits = <SearchHit>[];
    for (final m in meetings) {
      final subject = subjects[m.subjectId];
      if (!matchesWords('${m.title}\n${subject ?? ''}', words)) continue;
      hits.add(
        SearchHit(
          kind: SearchKind.lesson,
          title: m.title,
          subtitle: subject,
          excerpt: excerptAround(m.title, words),
          meetingId: m.id,
          at: m.createdAt,
        ),
      );
    }
    return _trim(hits);
  }

  Future<Iterable<SearchHit>> _transcripts(
    Map<int, Meeting> meetings,
    Map<int, String> subjects,
    List<String> words,
  ) async {
    final live = await (_db.select(
      _db.transcriptSegments,
    )..where((t) => t.content.isNotNull())).get();
    final refined = await (_db.select(
      _db.refinedSegments,
    )..where((t) => t.content.isNotNull())).get();

    // A refined window covers the same minutes as the live chunks inside it,
    // so a word present in both would otherwise be found twice. The refined
    // text is the better one, so it goes first and the live chunks it covers
    // are skipped.
    final hits = <SearchHit>[];
    final perMeeting = <int, int>{};
    final coveredRanges = <int, List<(int, int)>>{};

    void add(int meetingId, int? segmentId, String text) {
      final count = perMeeting[meetingId] ?? 0;
      if (count >= _perMeeting) return;
      final meeting = meetings[meetingId];
      if (meeting == null) return;
      perMeeting[meetingId] = count + 1;
      hits.add(
        SearchHit(
          kind: SearchKind.transcript,
          title: meeting.title,
          subtitle: subjects[meeting.subjectId],
          excerpt: excerptAround(text, words),
          meetingId: meetingId,
          segmentId: segmentId,
          at: meeting.createdAt,
        ),
      );
    }

    for (final w in refined) {
      coveredRanges.putIfAbsent(w.meetingId, () => []).add((
        w.startMs,
        w.endMs,
      ));
      if (!matchesWords(w.content!, words)) continue;
      add(w.meetingId, null, w.content!);
    }
    for (final s in live) {
      final covered = coveredRanges[s.meetingId]?.any(
        (r) => s.startMs >= r.$1 && s.startMs < r.$2,
      );
      if (covered ?? false) continue;
      if (!matchesWords(s.content!, words)) continue;
      add(s.meetingId, s.id, s.content!);
    }
    return _trim(hits);
  }

  Future<Iterable<SearchHit>> _notes(
    Map<int, String> subjects,
    List<String> words,
  ) async {
    final notes = await _db.select(_db.savedNotes).get();
    final hits = <SearchHit>[];
    for (final n in notes) {
      if (!matchesWords('${n.title}\n${n.content}', words)) continue;
      hits.add(
        SearchHit(
          kind: SearchKind.note,
          title: n.title,
          subtitle: subjects[n.folderId],
          excerpt: excerptAround(n.content, words),
          noteId: n.id,
          at: n.updatedAt,
        ),
      );
    }
    return _trim(hits);
  }

  Future<Iterable<SearchHit>> _cards(
    Map<int, String> subjects,
    List<String> words,
  ) async {
    final cards = await _db.select(_db.contextCards).get();
    final hits = <SearchHit>[];
    for (final c in cards) {
      if (!matchesWords(
        '${c.title}\n${c.content}\n${c.keywords ?? ''}',
        words,
      )) {
        continue;
      }
      hits.add(
        SearchHit(
          kind: SearchKind.card,
          title: c.title,
          subtitle: subjects[c.subjectId],
          excerpt: excerptAround(
            c.content.trim().isEmpty ? (c.keywords ?? '') : c.content,
            words,
          ),
          cardId: c.id,
          at: c.updatedAt,
        ),
      );
    }
    return _trim(hits);
  }

  Future<Iterable<SearchHit>> _chat(
    Map<int, Meeting> meetings,
    Map<int, String> subjects,
    List<String> words,
  ) async {
    final messages = await _db.select(_db.chatMessages).get();
    final hits = <SearchHit>[];
    for (final m in messages) {
      // An answer's short line and its explanation are as much part of the
      // lesson as what the student typed.
      final text = [
        m.body,
        m.short ?? '',
        m.detail ?? '',
      ].where((t) => t.trim().isNotEmpty).join('\n');
      if (text.trim().isEmpty || !matchesWords(text, words)) continue;
      final meeting = meetings[m.meetingId];
      if (meeting == null) continue;
      hits.add(
        SearchHit(
          kind: SearchKind.chat,
          title: meeting.title,
          subtitle: subjects[meeting.subjectId],
          excerpt: excerptAround(text, words),
          meetingId: m.meetingId,
          at: meeting.createdAt,
        ),
      );
    }
    return _trim(hits);
  }

  /// Newest first, capped — the order a person reads a result list in.
  List<SearchHit> _trim(List<SearchHit> hits) {
    hits.sort((a, b) {
      final at = a.at, bt = b.at;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });
    return hits.length <= _perKind ? hits : hits.sublist(0, _perKind);
  }
}
