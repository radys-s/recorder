import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/spacing.dart';
import '../../core/widgets/count_up.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/inset_group.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/study_cards_dao.dart';
import '../../learning/study_flow.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../subjects/subjects_providers.dart';
import 'exam_prep_screen.dart';
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
    final accent = context.accent;
    // Appears the first time something is due, and the number counts up to it.
    return Entrance(
      child: InsetGroup(
        label: 'Opakování',
        children: [
          ListRow(
            leadingSlot: 52,
            leading: const GradientIconTile(icon: Icons.style_outlined),
            title: 'Dnes zopakovat',
            subtitle: czechCount(due, 'kartička', 'kartičky', 'kartiček'),
            trailing: GradientMask(
              gradient: accent.textGradient,
              child: CountUp(
                value: due,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            onTap: () => Navigator.of(context).push(ReviewScreen.route()),
          ),
        ],
      ),
    );
  }
}

/// A subject's learning on its Přehled tab: the one thing to do next, then
/// review, quiz and cards as one flow.
///
/// [lessons] are the subject's lessons, newest first, without those waiting
/// out an undo; [withNotes] holds the ids of those that have výpisky.
class SubjectStudySection extends ConsumerWidget {
  const SubjectStudySection({
    super.key,
    required this.subjectId,
    this.lessons = const [],
    this.withNotes = const {},
  });

  final int subjectId;
  final List<Meeting> lessons;
  final Set<int> withNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(studyStatsProvider(subjectId)).valueOrNull;
    final perLesson =
        ref.watch(subjectLessonStudyProvider(subjectId)).valueOrNull ??
        const <int, StudyStats>{};
    final total = stats?.total ?? 0;
    final due = stats?.due ?? 0;
    final nav = Navigator.of(context);

    // The newest lesson with výpisky and no cards: where cards get made.
    final toCard = [
      for (final m in lessons)
        if (withNotes.contains(m.id) && (perLesson[m.id]?.total ?? 0) == 0) m,
    ];
    final withoutNotes = [
      for (final m in lessons)
        if (!withNotes.contains(m.id)) m,
    ];
    final next = recommendStudyStep(
      lessons: lessons.length,
      lessonsWithNotes: lessons.where((m) => withNotes.contains(m.id)).length,
      lessonsToCard: toCard.length,
      cards: total,
      due: due,
    );

    VoidCallback action() => switch (next.step) {
      StudyStep.reviewDue => () => nav.push(
        ReviewScreen.route(subjectId: subjectId),
      ),
      StudyStep.recordLesson => () => nav.popUntil((r) => r.isFirst),
      StudyStep.makeNotes => () => nav.push(
        MeetingDetailScreen.route(withoutNotes.first.id, initialTab: 1),
      ),
      StudyStep.makeCards => () => nav.push(
        MeetingDetailScreen.route(toCard.first.id, initialTab: 1),
      ),
      StudyStep.examPrep => () => nav.push(ExamPrepScreen.route(subjectId)),
    };

    final icon = switch (next.step) {
      StudyStep.reviewDue => Icons.replay_rounded,
      StudyStep.recordLesson => Icons.mic_none_rounded,
      StudyStep.makeNotes => Icons.description_outlined,
      StudyStep.makeCards => Icons.style_outlined,
      StudyStep.examPrep => Icons.quiz_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsetGroup(
          label: 'Co teď',
          horizontalInset: 0,
          dividerIndent: ListRow.textIndent + 28,
          children: [
            ListRow(
              leadingSlot: 52,
              leading: GradientIconTile(icon: icon),
              title: next.title,
              subtitle: next.subtitle,
              onTap: action(),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        InsetGroup(
          label: 'Učení',
          horizontalInset: 0,
          dividerIndent: ListRow.textIndent + 28,
          children: [
            ListRow(
              leadingSlot: 52,
              leading: const GradientIconTile(icon: Icons.replay_rounded),
              title: 'Opakovat',
              subtitle: total == 0
                  ? 'Kartičky vzniknou z výpisků hodin, nebo je přidej ručně.'
                  : '${czechCount(total, 'kartička', 'kartičky', 'kartiček')}'
                        ' · dnes ${due == 0 ? 'nic' : due}',
              chevron: due > 0,
              onTap: due == 0
                  ? null
                  : () => nav.push(ReviewScreen.route(subjectId: subjectId)),
            ),
            ListRow(
              leadingSlot: 52,
              leading: const GradientIconTile(icon: Icons.quiz_outlined),
              title: 'Před testem',
              subtitle: 'Kvíz z výpisků ukáže, co ještě nesedí.',
              onTap: () => nav.push(ExamPrepScreen.route(subjectId)),
            ),
            ListRow(
              leadingSlot: 52,
              leading: const GradientIconTile(icon: Icons.list_alt_rounded),
              title: 'Kartičky',
              subtitle: 'Upravit, pozastavit nebo přidat.',
              onTap: () => nav.push(StudyCardsScreen.route(subjectId)),
            ),
          ],
        ),
      ],
    );
  }
}
