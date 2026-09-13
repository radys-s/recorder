import 'package:flutter/material.dart';

import '../../../core/spacing.dart';
import '../../../ai/answer_source.dart';
import '../../../data/db/app_database.dart';
import 'answer_basis.dart';
import 'answer_sources.dart';

/// An answer, shown in the transcript right after the segment its question was
/// heard in.
///
/// Coloured rather than plain on purpose: the timeline is otherwise a wall of
/// uniform text, and the point of live answering is that a glance at the phone
/// is enough to find the thing that was not said out loud. `secondaryContainer`
/// specifically — `tertiaryContainer` is a near-twin of the error pink the
/// recording banner uses, and an answer that reads as a failure is worse than
/// no colour at all.
class AnswerCardTile extends StatelessWidget {
  const AnswerCardTile({super.key, required this.card});

  final AnswerCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    card.question,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            SelectableText(
              card.answer,
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
    );
  }
}
