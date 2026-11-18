import 'package:flutter/foundation.dart';

import '../core/search.dart';
import 'db/app_database.dart';

/// Uses the existing local tables and matching rules; no index or AI calls.
class SearchService {
  SearchService(this._db);
  final AppDatabase _db;

  /// Observe table invalidations without subscribing to the corpus itself.
  Stream<void> get changes => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.meetings,
          _db.subjects,
          _db.transcriptSegments,
          _db.refinedSegments,
          _db.meetingNotes,
          _db.savedNotes,
          _db.contextCards,
          _db.chatMessages,
        },
      )
      .watch()
      .map((_) {});

  Future<bool> hasLibraryContent() async {
    final row = await _db.customSelect('''
      SELECT EXISTS(SELECT 1 FROM meetings) OR
        EXISTS(SELECT 1 FROM saved_notes) OR
        EXISTS(SELECT 1 FROM context_cards) AS has_content
    ''').getSingle();
    return row.read<int>('has_content') != 0;
  }

  Future<List<SearchHit>> search(
    String query, {
    SearchFilter filter = const SearchFilter(),
    bool browse = false,
    int limit = 25,
  }) async {
    final words = searchWords(query);
    if (words.isEmpty && !browse) return const [];
    final subjects = {
      for (final s in await _db.subjectsDao.allSubjects())
        s.subject.id: s.subject.name,
    };
    final meetings = await _db.meetingsDao.allMeetingsOnce();
    final byId = {for (final m in meetings) m.id: m};
    final documents = <_SearchDocument>[];

    void add(
      SearchKind kind,
      String title,
      String text, {
      int? meetingId,
      int? segmentId,
      int? noteId,
      int? cardId,
      int? subjectId,
      required DateTime at,
    }) {
      final hit = SearchHit(
        kind: kind,
        title: title,
        excerpt: const SearchExcerpt.plain(''),
        subtitle: subjects[subjectId],
        meetingId: meetingId,
        segmentId: segmentId,
        noteId: noteId,
        cardId: cardId,
        subjectId: subjectId,
        at: at,
      );
      if (filter.allows(hit)) {
        documents.add(_SearchDocument(hit, text));
      }
    }

    for (final m in meetings) {
      add(
        SearchKind.lesson,
        m.title,
        m.title,
        meetingId: m.id,
        subjectId: m.subjectId,
        at: m.createdAt,
      );
    }
    // Filter-only browsing finds lessons, not every chunk of every lesson.
    if (!browse || words.isNotEmpty) {
      final refined = await _db.select(_db.refinedSegments).get();
      final ranges = <int, List<(int, int)>>{};
      for (final w in refined) {
        final m = byId[w.meetingId];
        if (m == null || w.content == null || w.content!.trim().isEmpty) {
          continue;
        }
        ranges.putIfAbsent(m.id, () => []).add((w.startMs, w.endMs));
        add(
          SearchKind.transcript,
          m.title,
          w.content!,
          meetingId: m.id,
          subjectId: m.subjectId,
          at: m.createdAt,
        );
      }
      for (final s in await _db.select(_db.transcriptSegments).get()) {
        final m = byId[s.meetingId];
        if (m == null || s.content == null || s.content!.trim().isEmpty) {
          continue;
        }
        if (ranges[m.id]?.any((r) => s.startMs >= r.$1 && s.startMs < r.$2) ??
            false) {
          continue;
        }
        add(
          SearchKind.transcript,
          m.title,
          s.content!,
          meetingId: m.id,
          segmentId: s.id,
          subjectId: m.subjectId,
          at: m.createdAt,
        );
      }
      for (final n in await _db.select(_db.meetingNotes).get()) {
        final m = byId[n.meetingId];
        if (m == null || n.content == null || n.content!.trim().isEmpty) {
          continue;
        }
        add(
          SearchKind.lessonNotes,
          m.title,
          n.content!,
          meetingId: m.id,
          subjectId: m.subjectId,
          at: m.createdAt,
        );
      }
      for (final m in await _db.select(_db.chatMessages).get()) {
        final lesson = byId[m.meetingId];
        if (lesson == null) continue;
        final text = [m.body, m.short ?? '', m.detail ?? ''].join('\n');
        if (text.trim().isEmpty) continue;
        add(
          SearchKind.chat,
          lesson.title,
          text,
          meetingId: lesson.id,
          subjectId: lesson.subjectId,
          at: lesson.createdAt,
        );
      }
    }
    for (final n in await _db.select(_db.savedNotes).get()) {
      add(
        SearchKind.note,
        n.title,
        n.content,
        noteId: n.id,
        subjectId: n.folderId,
        at: n.updatedAt,
      );
    }
    for (final c in await _db.select(_db.contextCards).get()) {
      add(
        SearchKind.card,
        c.title,
        '${c.content}\n${c.keywords ?? ''}',
        cardId: c.id,
        subjectId: c.subjectId,
        at: c.updatedAt,
      );
    }
    // Normalize and scan long transcripts away from the native UI isolate.
    // compute executes inline on web; mobile performance is the target here.
    return compute(_matchDocuments, (documents, words, limit));
  }
}

class _SearchDocument {
  const _SearchDocument(this.hit, this.excerptText);
  final SearchHit hit;
  final String excerptText;
}

List<SearchHit> _matchDocuments(
  (List<_SearchDocument>, List<String>, int) input,
) {
  final (documents, words, limit) = input;
  documents.sort((a, b) => b.hit.at!.compareTo(a.hit.at!));
  final counts = <SearchKind, int>{};
  final perMeeting = <int, int>{};
  final hits = <SearchHit>[];
  for (final document in documents) {
    final h = document.hit;
    if ((counts[h.kind] ?? 0) >= limit) continue;
    if (h.kind == SearchKind.transcript &&
        (perMeeting[h.meetingId] ?? 0) >= 3) {
      continue;
    }
    if (words.isNotEmpty &&
        !matchesWords(
          '${h.title}\n${h.subtitle ?? ''}\n${document.excerptText}',
          words,
        )) {
      continue;
    }
    counts[h.kind] = (counts[h.kind] ?? 0) + 1;
    if (h.kind == SearchKind.transcript) {
      perMeeting[h.meetingId!] = (perMeeting[h.meetingId] ?? 0) + 1;
    }
    hits.add(
      SearchHit(
        kind: h.kind,
        title: h.title,
        subtitle: h.subtitle,
        excerpt: excerptAround(document.excerptText, words),
        meetingId: h.meetingId,
        segmentId: h.segmentId,
        noteId: h.noteId,
        cardId: h.cardId,
        subjectId: h.subjectId,
        at: h.at,
      ),
    );
  }
  return hits;
}
