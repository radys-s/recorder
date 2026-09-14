import 'package:flutter/material.dart';

import '../spacing.dart';

/// "There is nothing here yet, and here is what to do about it."
///
/// Replaces three hand-rolled versions that had drifted apart in padding,
/// colour and whether they said anything actionable at all.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;

  /// One short line naming the emptiness.
  final String title;

  /// Optional second line saying how to fill it. Worth writing: an empty state
  /// that only states the obvious is a wasted screen.
  final String? message;

  /// Optional button that does the thing [message] describes.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: ConstrainedBox(
          // Centred text wider than this stops reading as a sentence.
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A tinted disc rather than a bare grey glyph: the bare icon read
              // as a disabled control, not as an illustration.
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: Gap.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Gap.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
