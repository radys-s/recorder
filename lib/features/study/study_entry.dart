import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/spacing.dart';
import '../../core/widgets/inset_group.dart';
import '../subjects/subjects_providers.dart';
import 'review_screen.dart';
import 'study_cards_screen.dart';
import 'study_providers.dart';

/// „Dnes zopakovat · N" on the dashboard; nothing when nothing is due.
///
/// The due counts are computed against the moment they were first read, so
/// coming back to the app (possibly on another day) recomputes them.
class StudyDueGroup extends ConsumerStatefulWidget {
  const StudyDueGroup({super.key});

  @override
  ConsumerState<StudyDueGroup> createState() => _StudyDueGroupState();
}

class _StudyDueGroupState extends ConsumerState<StudyDueGroup> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(dueStudyCountProvider);
        ref.invalidate(studyStatsProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final due = ref.watch(dueStudyCountProvider(null)).valueOrNull ?? 0;
    if (due == 0) return const SizedBox.shrink();
    return InsetGroup(
      label: 'Opakování',
      children: [
        ListRow(
          leadingSlot: 52,
          leading: const GradientIconTile(icon: Icons.style_outlined),
          title: 'Dnes zopakovat',
          subtitle: czechCount(due, 'kartička', 'kartičky', 'kartiček'),
          onTap: () => Navigator.of(context).push(ReviewScreen.route()),
        ),
      ],
    );
  }
}

/// A subject's study cards on its Přehled tab: counts, review, manage.
class SubjectStudySection extends ConsumerWidget {
  const SubjectStudySection({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(studyStatsProvider(subjectId)).valueOrNull;
    final total = stats?.total ?? 0;
    final due = stats?.due ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Opakování', style: theme.textTheme.titleSmall),
        const SizedBox(height: Gap.xs),
        Text(
          total == 0
              ? 'Kartičky vzniknou z výpisků hodin, nebo je přidej ručně.'
              : '${czechCount(total, 'kartička', 'kartičky', 'kartiček')}'
                    ' · dnes ${due == 0 ? 'nic' : due}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: due == 0
                    ? null
                    : () =>
                          Navigator.of(context)
                              .push(ReviewScreen.route(subjectId: subjectId)),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Opakovat'),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: FilledButton.tonalIcon(
                style: tonalButtonStyle(context),
                onPressed: () =>
                    Navigator.of(context)
                        .push(StudyCardsScreen.route(subjectId)),
                icon: const Icon(Icons.style_outlined),
                label: const Text('Kartičky'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
