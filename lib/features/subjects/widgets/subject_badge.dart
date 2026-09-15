import 'package:flutter/material.dart';

import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';
import '../subjects_providers.dart';

/// A colour dot and the subject's name, the way a subject is named everywhere
/// outside its own screen.
class SubjectBadge extends StatelessWidget {
  const SubjectBadge({super.key, required this.subject, this.dense = true});

  final Subject subject;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = subjectColor(context, subject.colorIndex);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Gap.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SubjectDot(color: color, size: dense ? 8 : 10),
          const SizedBox(width: Gap.xs + 2),
          Flexible(
            child: Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.labelMedium)
                  ?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectDot extends StatelessWidget {
  const SubjectDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// A rounded tile with the subject's initial, for list rows.
class SubjectAvatar extends StatelessWidget {
  const SubjectAvatar({super.key, required this.subject, this.size = 40});

  final Subject subject;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = subjectColor(context, subject.colorIndex);
    final initial = subject.name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Gap.md),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
