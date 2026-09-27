import 'package:flutter/material.dart';

import '../../../core/accent.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/inset_group.dart' show SubjectDot;
import '../../../data/db/app_database.dart';
import '../subjects_providers.dart';

export '../../../core/widgets/inset_group.dart' show SubjectDot;

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
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.08),
          ],
        ),
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
        gradient: subjectGradient(color),
        borderRadius: BorderRadius.circular(Gap.md),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color:
                  ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
