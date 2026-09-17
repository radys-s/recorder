import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/tables/refined_segments_table.dart';
import '../../data/db/tables/subject_terms_table.dart';
import '../../stt/term_corrections.dart';

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// The words of [text] with their offsets, for the fix sheet's chips.
List<({String word, int start, int end})> wordsOf(String text) => [
  for (final m in _word.allMatches(text))
    (word: m[0]!, start: m.start, end: m.end),
];

/// When each meeting's transcript was last corrected in this run of the app,
/// so the notes tab can say its výpisky were made from an older text.
final transcriptEditedAtProvider = StateProvider<Map<int, DateTime>>(
  (ref) => const {},
);

/// Replaces [heard] with [term] as a whole word in every live segment and
/// refined window of the meeting, keeping each first original. With
/// [remember] and a subject, the pair is stored so later lessons of that
/// subject are fixed too. Returns how many rows changed.
Future<int> fixWordInMeeting(
  AppDatabase db, {
  required int meetingId,
  required String heard,
  required String term,
  required bool remember,
}) async {
  final cleanHeard = heard.trim();
  final cleanTerm = term.trim();
  if (cleanHeard.isEmpty || cleanTerm.isEmpty) return 0;
  final pairs = [(heard: cleanHeard, term: cleanTerm)];

  var changed = 0;
  for (final s in await db.transcriptSegmentsDao.segmentsForMeeting(
    meetingId,
  )) {
    final text = s.content;
    if (text == null) continue;
    final r = applyTermCorrections(text, pairs);
    if (r.applied.isEmpty) continue;
    await db.transcriptSegmentsDao.correctSegment(s.id, r.text);
    changed++;
  }
  for (final w in await db.refinedSegmentsDao.windows(meetingId)) {
    final text = w.content;
    if (text == null || w.status != RefinedStatus.ready) continue;
    final r = applyTermCorrections(text, pairs);
    if (r.applied.isEmpty) continue;
    await db.refinedSegmentsDao.correctWindow(w.id, r.text);
    changed++;
  }

  if (remember) {
    final meeting = await db.meetingsDao.watchMeetingByIdOnce(meetingId);
    final subjectId = meeting?.subjectId;
    // addTerm refuses a heard form identical to the term; the plain term
    // still helps the transcription spell it.
    if (subjectId != null) {
      try {
        await db.subjectsDao.addTerm(
          subjectId,
          cleanTerm,
          heard: cleanHeard,
          source: TermSource.correction,
        );
      } on ArgumentError {
        await db.subjectsDao.addTerm(
          subjectId,
          cleanTerm,
          source: TermSource.correction,
        );
      }
    }
  }
  return changed;
}
