import 'package:flutter/material.dart';

import '../../../core/spacing.dart';
import '../../../ai/answer_source.dart';
import '../../../data/db/app_database.dart';
import 'answer_basis.dart';
import 'answer_sources.dart';

/// The newest answer, pinned above the transcript while the meeting is being
/// recorded.
///
/// The timeline card is the record; this is the one the user actually reads
/// mid-meeting, because during a recording the list is scrolling and the
/// answer would slide past. Dismissing hides only this panel — the card stays
/// in the transcript.
class LatestAnswerPanel extends StatelessWidget {
  const LatestAnswerPanel({
    super.key,
    required this.card,
    required this.onDismiss,
  });

  final AnswerCard card;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Pinned above a list that scrolls underneath it, so it has to read as a
    // separate layer. `Material(elevation:)` is no use here: the panel opens
    // inside a SizeTransition, which wraps its child in a ClipRect, and a
    // shadow is drawn outside the child's bounds — so it would be clipped away
    // on every frame. This paints the same falloff inside the panel's own box
    // instead, which also means it grows and shrinks with the panel.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _panel(theme, scheme),
        Container(
          height: 6,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.shadow.withValues(alpha: 0.13),
                scheme.shadow.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(ThemeData theme, ColorScheme scheme) {
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        size: 14,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: Gap.xs),
                      Expanded(
                        child: Text(
                          card.question,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  // Capped: the panel steals height from the transcript, and a
                  // long answer is still readable in full on its timeline card.
                  Text(
                    card.answer,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                      height: 1.4,
                    ),
                  ),
                  AnswerBasisBadge(basis: card.basis),
                  AnswerSources(sources: decodeAnswerSources(card.sources)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: scheme.onSecondaryContainer,
              tooltip: 'Skrýt odpověď',
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
