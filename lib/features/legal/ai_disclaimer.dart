import 'package:flutter/material.dart';

import '../../core/spacing.dart';
import '../../legal/legal_texts.dart';

/// A quiet line under AI-written text: it can be wrong.
class AiDisclaimer extends StatelessWidget {
  const AiDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: color),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              kAiDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
