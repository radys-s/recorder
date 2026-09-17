import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../../../core/spacing.dart';
import '../../../core/theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/tables/refined_segments_table.dart';

/// Several minutes of the refined transcript, or the failure of one window.
class RefinedWindowTile extends StatelessWidget {
  const RefinedWindowTile({
    super.key,
    required this.window,
    required this.onRetry,
    this.onLongPress,
  });

  final RefinedSegment window;
  final VoidCallback onRetry;

  /// Opens the word fix sheet; see [TranscriptSegmentTile.onLongPress].
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = window.status == RefinedStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatClockMs(window.startMs)}–${formatClockMs(window.endMs)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontFeatures: kTabularFigures,
            ),
          ),
          const SizedBox(height: Gap.xs),
          if (failed) ...[
            Row(
              children: [
                Icon(Icons.error_outline,
                    size: 16, color: theme.colorScheme.error),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: Text(
                    'Tuhle část se nepodařilo vylepšit, níž je živý přepis.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
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
          ] else if (onLongPress == null)
            SelectableText(
              window.content?.trim() ?? '',
              style: theme.textTheme.bodyLarge,
            )
          else
            Semantics(
              onLongPressHint: 'Opravit slovo',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: onLongPress,
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    window.content?.trim() ?? '',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
