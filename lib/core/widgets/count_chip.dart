import 'package:flutter/material.dart';

import '../accent.dart';
import '../spacing.dart';

/// A filter chip with a count after its label; the selected one gets the
/// accent's lit outline, the rest a plain one.
class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    this.avatar,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = context.accent;
    final radius = BorderRadius.circular(Gap.sm);

    // The selected chip gets the accent's lit outline, the rest a plain one.
    return ChoiceChip(
      avatar: avatar,
      selected: selected,
      onSelected: (_) => onSelected(),
      shape: selected
          ? GradientRoundedRectangleBorder(
              borderRadius: radius,
              gradient: accent.outlineGradient(),
              width: 1.2,
            )
          : RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: scheme.outlineVariant),
            ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: Gap.sm - 2),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? accent.text : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
