import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';
import '../subjects_providers.dart';
import 'lesson_sheet.dart';
import 'subject_badge.dart';

/// „Čeština · Babička +1" under a lesson's app bar: what the AI knows about
/// this lesson, and the way to change it mid-lesson.
class LessonContextStrip extends ConsumerWidget {
  const LessonContextStrip({super.key, required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectId = meeting.subjectId;
    if (subjectId == null) return const SizedBox.shrink();

    final subject = ref.watch(subjectProvider(subjectId)).valueOrNull;
    if (subject == null) return const SizedBox.shrink();
    final cards = ref.watch(pinnedCardsProvider(meeting.id)).valueOrNull ??
        const <ContextCard>[];

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = StringBuffer(subject.name);
    if (cards.isNotEmpty) {
      label.write(' · ${cards.first.title}');
      if (cards.length > 1) label.write(' +${cards.length - 1}');
    }

    return Material(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => showLessonSheet(context, ref, meeting),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg, vertical: Gap.sm + 2),
          child: Row(
            children: [
              SubjectDot(color: subjectColor(context, subject.colorIndex)),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  label.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if ((meeting.rules ?? '').isNotEmpty) ...[
                Icon(Icons.rule, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: Gap.sm),
              ],
              Icon(Icons.tune, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
