import 'package:flutter/material.dart';

import '../spacing.dart';

/// A titled section inside a settings-style column.
///
/// The rule, spacing, title and description block was copy-pasted three times
/// in Settings, which is exactly the kind of thing that ends up with one copy a
/// few pixels off from the others.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.description,
    this.first = false,
  });

  final String title;

  /// The small print under the title. Usually explains a consequence the
  /// control itself cannot.
  final String? description;

  /// Set on the topmost section, which sits directly under the app bar and so
  /// needs neither the rule nor the space above it.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Air instead of a rule: grouped sections read as separate by spacing
        // and weight alone, the way iOS settings do.
        if (!first) const SizedBox(height: Gap.xxl),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: Gap.xs),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Gap.md),
      ],
    );
  }
}
