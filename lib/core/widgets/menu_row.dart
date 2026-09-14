import 'package:flutter/material.dart';

import '../spacing.dart';

/// An icon and a label for a popup menu item. [destructive] paints both in the
/// error colour, so „Smazat" does not sit in a menu looking like „Přejmenovat".
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  /// Mirrors the item's own `enabled`, which greys text but not a custom
  /// colour — without it a disabled „Smazat" would still be bright red.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : destructive
            ? scheme.error
            : scheme.onSurface;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: Gap.md),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
