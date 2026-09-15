import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/spacing.dart';
import '../../../ai/answer_source.dart';
import '../../../data/db/app_database.dart';
import '../../subjects/subjects_providers.dart';
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
class AnswerCardTile extends ConsumerWidget {
  const AnswerCardTile({super.key, required this.card});

  final AnswerCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardId = card.cardId;
    final cardTitle = cardId == null
        ? null
        : ref.watch(contextCardProvider(cardId)).valueOrNull?.title;

    return AnswerBubble(
      question: card.question,
      short: card.answer,
      detail: card.detail,
      basis: card.basis,
      cardTitle: cardTitle,
      sources: decodeAnswerSources(card.sources),
    );
  }
}

/// The body shared by automatic answers and chat replies: the question, the
/// short answer in bold, and the explanation behind a tap.
class AnswerBubble extends StatefulWidget {
  const AnswerBubble({
    super.key,
    required this.question,
    required this.short,
    this.detail,
    this.basis = 'meeting',
    this.cardTitle,
    this.sources = const [],
    this.icon = Icons.lightbulb_outline,
  });

  final String? question;
  final String short;
  final String? detail;
  final String basis;
  final String? cardTitle;
  final List<AnswerSource> sources;
  final IconData icon;

  @override
  State<AnswerBubble> createState() => _AnswerBubbleState();
}

class _AnswerBubbleState extends State<AnswerBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onColor = scheme.onSecondaryContainer;
    final detail = widget.detail?.trim() ?? '';
    final hasDetail = detail.isNotEmpty;

    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.symmetric(vertical: Gap.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasDetail ? () => setState(() => _expanded = !_expanded) : null,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.question case final q? when q.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, size: 16, color: onColor),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        q,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: onColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.short,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onColor,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (hasDetail)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: onColor,
                      semanticLabel:
                          _expanded ? 'Skrýt vysvětlení' : 'Zobrazit vysvětlení',
                    ),
                ],
              ),
              AnimatedSize(
                duration:
                    reducedMotion(context) ? Duration.zero : AppDuration.quick,
                curve: AppCurve.standard,
                alignment: Alignment.topLeft,
                child: hasDetail && _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: Gap.sm),
                        child: SelectableText(
                          detail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onColor,
                            height: 1.4,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              AnswerBasisBadge(basis: widget.basis, cardTitle: widget.cardTitle),
              AnswerSources(sources: widget.sources),
            ],
          ),
        ),
      ),
    );
  }
}
