import 'package:flutter/material.dart';

import '../../../core/spacing.dart';

/// Where an answer came from, said out loud in the UI.
///
/// The user's standing rule for this app is that it must never put words in
/// their mouth. A live answer can legitimately come from outside the room — a
/// definition, a rule, a piece of arithmetic, a page on the internet — but then
/// the reader has to be able to tell at a glance, because they may be about to
/// repeat it to the people sitting around them.
///
/// An answer drawn from the meeting itself gets no badge: it is the normal
/// case, and a label on every card would be noise rather than information.
///
/// A chat reply stores a card basis as `card:<title>`, since its row has no
/// card column; an automatic answer passes the title as [cardTitle].
({String label, IconData icon})? answerBasisBadge(
  String basis, {
  String? cardTitle,
}) {
  if (basis == 'card' || basis.startsWith('card:')) {
    final title = cardTitle ??
        (basis.startsWith('card:') ? basis.substring(5).trim() : '');
    return (
      label: title.isEmpty ? 'Z karty' : 'Z karty „$title"',
      icon: Icons.style_outlined,
    );
  }
  return switch (basis) {
      'web' => (label: 'Z internetu', icon: Icons.public),
      'knowledge' => (
          label: 'Obecná znalost, nezaznělo na schůzce',
          icon: Icons.info_outline,
        ),
      'unknown' => (
          label: 'Na schůzce zatím nezaznělo',
          icon: Icons.info_outline,
        ),
      _ => null,
    };
}

/// The badge itself, or nothing at all for an answer that came from the
/// meeting. Deliberately quiet — it is a caveat, not a headline.
class AnswerBasisBadge extends StatelessWidget {
  const AnswerBasisBadge({super.key, required this.basis, this.cardTitle});

  final String basis;
  final String? cardTitle;

  @override
  Widget build(BuildContext context) {
    final badge = answerBasisBadge(basis, cardTitle: cardTitle);
    if (badge == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(badge.icon, size: 13, color: color),
          const SizedBox(width: Gap.xs),
          Expanded(
            child: Text(
              badge.label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
