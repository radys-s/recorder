import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../../../core/motion.dart';
import '../../../core/spacing.dart';
import '../../../core/theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/tables/transcript_segments_table.dart';

/// One chunk of the transcript.
///
/// A segment exists from the moment its audio is written, long before its text
/// comes back, so the tile has to be readable in all four states — that is what
/// makes the transcript feel live instead of appearing in one lump at the end.
class TranscriptSegmentTile extends StatelessWidget {
  const TranscriptSegmentTile({
    super.key,
    required this.segment,
    required this.onRetry,
    this.onLongPress,
  });

  final TranscriptSegment segment;
  final VoidCallback onRetry;

  /// Opens the word fix sheet. The text is then plain rather than selectable,
  /// because selection would swallow the long-press; the sheet copies it.
  final VoidCallback? onLongPress;

  /// Identifies which of the four bodies is showing, so [AnimatedSwitcher] can
  /// tell "the same body, rebuilt" from "a different body, swap it".
  String get _bodyKey {
    if (segment.status == SegmentStatus.failed) return 'failed';
    if (segment.content != null) return 'text';
    return segment.status == SegmentStatus.uploading ? 'uploading' : 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = reducedMotion(context);

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${formatClockMs(segment.startMs)}–${formatClockMs(segment.endMs)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFeatures: kTabularFigures,
                ),
              ),
              const SizedBox(width: Gap.sm),
              AnimatedOpacity(
                opacity: segment.status == SegmentStatus.uploading ? 1 : 0,
                duration: reduced ? Duration.zero : AppDuration.quick,
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          // The product's core moment. A chunk sits as "Čeká na přepis…" for
          // twenty seconds and then becomes real words; swapping that with no
          // transition reads as a glitch rather than as an arrival.
          //
          // Duration.zero under reduced motion swaps instantly and leaves the
          // new body fully opaque, which is the correct reduced-motion state
          // rather than a frozen half-faded one.
          AnimatedSwitcher(
            duration: reduced ? Duration.zero : AppDuration.base,
            switchInCurve: AppCurve.standard,
            switchOutCurve: AppCurve.exit,
            // The default layout builder centres the stack, so a one-line
            // placeholder becoming three lines of text would drift sideways
            // and upward mid-transition. Top-left pins both to the same
            // corner.
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 6 * (1 - animation.value)),
                  child: child,
                ),
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_bodyKey),
              child: _body(theme),
            ),
          ),
        ],
      ),
    );
    if (onLongPress == null || segment.content == null) return tile;
    return Semantics(
      onLongPressHint: 'Opravit slovo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: tile,
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (segment.status == SegmentStatus.failed) {
      return _FailedBody(onRetry: onRetry);
    }
    if (segment.content != null) {
      return onLongPress == null
          ? SelectableText(segment.content!, style: theme.textTheme.bodyLarge)
          : Text(segment.content!, style: theme.textTheme.bodyLarge);
    }
    return Text(
      segment.status == SegmentStatus.uploading
          ? 'Přepisuje se…'
          : 'Čeká na přepis…',
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.outline,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// A segment the queue gave up on. The audio is still on disk, so this is
/// recoverable — without the retry action a parked chunk would be a permanent
/// hole in the transcript with no way out.
class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: Gap.xs),
            Text(
              'Přepis se nepodařil',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          // Default TextButton insets made failed rows visibly taller than
          // every other row in the list.
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Zkusit znovu'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
