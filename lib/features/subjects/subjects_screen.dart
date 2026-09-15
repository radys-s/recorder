import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../data/db/daos/subjects_dao.dart';
import '../settings/settings_screen.dart';
import 'subject_actions.dart';
import 'subject_detail_screen.dart';
import 'subjects_providers.dart';
import 'widgets/subject_badge.dart';

/// Every subject, each with the cards, lessons and notes that belong to it.
class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  /// Subject ids whose entrance has played; see `MeetingsListScreen._seen`.
  final _seen = <int>{};

  Future<void> _create() async {
    final id = await createSubjectFlow(context, ref);
    if (id != null && mounted) {
      await Navigator.of(context).push(SubjectDetailScreen.route(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Předměty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nový předmět'),
      ),
      body: AsyncView(
        value: subjects,
        message: 'Předměty se nepodařilo načíst.',
        onRetry: () => ref.invalidate(subjectsProvider),
        builder: _buildList,
      ),
    );
  }

  Widget _buildList(List<SubjectSummary> list) {
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.school_outlined,
        title: 'Zatím žádné předměty',
        message: 'Předmět drží karty s kontextem — knihy, témata, pojmy. '
            'AI je pak použije, když v hodině padne otázka.',
      );
    }

    final firstPaint = _seen.isEmpty;
    final entering = <int, int>{};
    for (final s in list) {
      if (_seen.add(s.subject.id)) entering[s.subject.id] = entering.length;
    }

    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.fabClearance),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final summary = list[i];
        final order = entering[summary.subject.id];
        return Entrance(
          enabled: order != null,
          delay: firstPaint && order != null
              ? AppMotion.staggerDelay(order)
              : Duration.zero,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: _SubjectCard(summary: summary),
          ),
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.summary});

  final SubjectSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = [
      czechCount(summary.cardCount, 'karta', 'karty', 'karet'),
      czechCount(summary.lessonCount, 'hodina', 'hodiny', 'hodin'),
      if (summary.noteCount > 0)
        czechCount(summary.noteCount, 'poznámka', 'poznámky', 'poznámek'),
    ].join(' · ');

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(SubjectDetailScreen.route(summary.subject.id)),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              SubjectAvatar(subject: summary.subject, size: 44),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      counts,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
