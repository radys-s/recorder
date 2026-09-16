import '../core/constants.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/refined_segments_table.dart';

/// One planned window of the refined pass: the live chunks it re-hears.
class WindowPlan {
  const WindowPlan(this.chunks);

  final List<TranscriptSegment> chunks;

  int get startMs => chunks.first.startMs;
  int get endMs => chunks.last.endMs;
}

/// Groups a recording's chunks, in order, into windows of about [target].
///
/// Boundaries are chunk boundaries, which the chunker already put at pauses.
/// Every chunk counts — including the ones the live pass skipped as silence,
/// since that gate is exactly what drops a quiet teacher. A window closes on
/// the first chunk that takes it to [target]; a last window shorter than
/// [minLast] joins the one before it rather than going out as a scrap of
/// audio with no context.
List<WindowPlan> planWindows(
  List<TranscriptSegment> segments, {
  required Duration target,
  Duration minLast = kRefinedMinLastWindow,
}) {
  final ordered = [...segments]..sort((a, b) => a.sequence.compareTo(b.sequence));
  final windows = <List<TranscriptSegment>>[];
  var current = <TranscriptSegment>[];
  for (final s in ordered) {
    current.add(s);
    if (current.last.endMs - current.first.startMs >= target.inMilliseconds) {
      windows.add(current);
      current = <TranscriptSegment>[];
    }
  }
  if (current.isNotEmpty) {
    final length = current.last.endMs - current.first.startMs;
    if (windows.isNotEmpty && length < minLast.inMilliseconds) {
      windows.last.addAll(current);
    } else {
      windows.add(current);
    }
  }
  return [for (final w in windows) WindowPlan(w)];
}

/// The chunks of [segments] a window covers, by time rather than id: windows
/// are stored as a time range, and re-planning must not depend on row ids.
List<TranscriptSegment> chunksIn(
  List<TranscriptSegment> segments,
  int startMs,
  int endMs,
) =>
    [
      for (final s in segments)
        if (_midpoint(s) >= startMs && _midpoint(s) < endMs) s,
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));

int _midpoint(TranscriptSegment s) => (s.startMs + s.endMs) ~/ 2;

/// A stretch of the transcript as it should be read.
sealed class TranscriptPiece {
  const TranscriptPiece();
  int get startMs;
}

class RefinedPiece extends TranscriptPiece {
  const RefinedPiece(this.window);
  final RefinedSegment window;
  @override
  int get startMs => window.startMs;
}

class LivePiece extends TranscriptPiece {
  const LivePiece(this.segment);
  final TranscriptSegment segment;
  @override
  int get startMs => segment.startMs;
}

/// Ready windows replace the live segments whose time they cover; everything
/// else — windows still waiting, failed, or not planned at all — falls back
/// to the live segments.
///
/// A ready window that heard nothing does not hide live text in its range:
/// losing words the live pass did hear is worse than keeping a possible
/// hallucination the rate guard already let through.
List<TranscriptPiece> refinedOrLivePieces(
  List<TranscriptSegment> live,
  List<RefinedSegment> refined,
) {
  final ready = [
    for (final w in refined)
      if (w.status == RefinedStatus.ready) w,
  ];
  final pieces = <TranscriptPiece>[];
  final covered = <int>{};
  for (final w in ready) {
    final inside = chunksIn(live, w.startMs, w.endMs);
    final text = w.content?.trim() ?? '';
    final liveText = inside.any((s) => s.content?.trim().isNotEmpty ?? false);
    if (text.isEmpty && liveText) continue;
    covered.addAll(inside.map((s) => s.id));
    pieces.add(RefinedPiece(w));
  }
  for (final s in live) {
    if (!covered.contains(s.id)) pieces.add(LivePiece(s));
  }
  pieces.sort((a, b) => a.startMs.compareTo(b.startMs));
  return pieces;
}

/// The best transcript there is, as one text: what notes and questions after
/// the lesson reason over.
String refinedOrLiveTranscript(
  List<TranscriptSegment> live,
  List<RefinedSegment> refined,
) =>
    [
      for (final piece in refinedOrLivePieces(live, refined))
        if (switch (piece) {
          RefinedPiece(:final window) => window.content?.trim(),
          LivePiece(:final segment) => segment.content?.trim(),
        }
            case final text? when text.isNotEmpty)
          text,
    ].join(' ');
