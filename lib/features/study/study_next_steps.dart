import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/spacing.dart';
import '../../core/widgets/inset_group.dart';
import '../../learning/study_flow.dart';
import '../subjects/subjects_providers.dart';
import 'exam_prep_screen.dart';
import 'review_screen.dart';
import 'study_cards_screen.dart';
import 'study_providers.dart';

/// One concrete thing to do after a study step.
class NextStep {
  const NextStep({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
}

/// „Co dál": the rows that end a review or a quiz, so learning never stops at
/// a dead end.
class NextStepsGroup extends StatelessWidget {
  const NextStepsGroup({super.key, required this.steps});

  final List<NextStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return InsetGroup(
      label: 'Co dál',
      dividerIndent: ListRow.textIndent + 28,
      children: [
        for (final s in steps)
          ListRow(
            leadingSlot: 52,
            leading: GradientIconTile(icon: s.icon),
            title: s.title,
            subtitle: s.subtitle,
            onTap: s.onTap,
          ),
      ],
    );
  }
}

/// The steps that follow the work on a subject: what is left to review, a
/// quiz, the cards, and the lesson the material came from.
///
/// Pushed screens replace the current one, so the student walks forward
/// through the flow instead of piling screens up behind a „Zpět".
List<NextStep> subjectNextSteps(
  BuildContext context, {
  required int subjectId,
  int dueLeft = 0,
  bool includeReview = true,
  bool replace = true,
  int? meetingId,
}) {
  final nav = Navigator.of(context);
  Future<void> go(Route<void> route) =>
      replace ? nav.pushReplacement(route) : nav.push(route);
  return [
    if (includeReview && dueLeft > 0)
      NextStep(
        icon: Icons.replay_rounded,
        title: 'Zopakovat zbytek předmětu',
        subtitle: czechDue(dueLeft),
        onTap: () => go(ReviewScreen.route(subjectId: subjectId)),
      ),
    NextStep(
      icon: Icons.quiz_outlined,
      title: 'Vyzkoušet se před testem',
      subtitle: 'Kvíz z výpisků ukáže, co ještě nesedí.',
      onTap: () => go(ExamPrepScreen.route(subjectId)),
    ),
    NextStep(
      icon: Icons.style_outlined,
      title: 'Kartičky předmětu',
      subtitle: 'Upravit, pozastavit nebo přidat.',
      onTap: () => go(StudyCardsScreen.route(subjectId)),
    ),
  ];
}

/// „3 kartičky čekají dnes" for a remaining-due row.
String czechDue(int n) =>
    '${czechCount(n, 'kartička', 'kartičky', 'kartiček')} čeká dnes';

/// When the next card after today falls due, as one line; null when nothing
/// is scheduled. Reads the provider once, so it settles after the session.
class NextDueLine extends ConsumerWidget {
  const NextDueLine({super.key, this.subjectId, this.meetingId});

  final int? subjectId;
  final int? meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref
        .watch(
          studyNextDueProvider((subjectId: subjectId, meetingId: meetingId)),
        )
        .valueOrNull;
    if (next == null) return const SizedBox.shrink();
    final now = ref.read(studyClockProvider)();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, 0),
      child: Text(
        'Další kartičky přijdou na řadu ${describeDueDay(next, now)}.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
