import 'package:flutter/material.dart';

import '../spacing.dart';

/// What a chip is saying, rather than what colour it should be. Naming the
/// meaning keeps the palette decision in one place — and keeps "this failed"
/// from being styled three different ways on three screens.
enum ChipTone {
  /// A fact about the recording that is not a problem: `Přerušeno`.
  neutral,

  /// Something still running. Reads as motion without actually animating,
  /// which matters in a list that can hold dozens of rows.
  progress,

  /// Something the user may want to do something about.
  alert,
}

/// A small pill naming one state of a row.
///
/// The meetings list used to say all of this in a single dot-joined sentence —
/// `Dnes 9:28 · 1:22 · přepisuje se 3/8 · 2× chyba · přerušeno` — where a
/// failure read as more text rather than as a state, and the eye had no way to
/// find the one row that needed attention. Chips make the exceptional cases
/// visible at a glance and let the ordinary row stay quiet.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.tone = ChipTone.neutral,
  });

  final IconData icon;
  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (background, foreground) = switch (tone) {
      ChipTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      ChipTone.progress => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      ChipTone.alert => (scheme.errorContainer, scheme.onErrorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.sm,
        vertical: Gap.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Gap.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: Gap.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
