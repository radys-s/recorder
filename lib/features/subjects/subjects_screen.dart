import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/pressable.dart';
import '../../data/db/daos/subjects_dao.dart';
import '../settings/settings_screen.dart';
import 'subject_actions.dart';
import 'subject_detail_screen.dart';
import 'subjects_providers.dart';
import 'timetable_import_screen.dart';

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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // The Scaffold lifts its button by viewPadding only, and the floating
    // navigation bar arrives as padding; without this the button sits under
    // the bar.
    final fabLift = (bottomInset - MediaQuery.viewPaddingOf(context).bottom)
        .clamp(0.0, double.infinity);

    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabLift),
        child: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Nový předmět'),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Předměty'),
            actions: [
              IconButton(
                icon: const Icon(Icons.document_scanner_outlined),
                tooltip: 'Importovat rozvrh z obrázku',
                onPressed: () => importTimetableFlow(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Nastavení',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          AsyncSliver(
            value: subjects,
            message: 'Předměty se nepodařilo načíst.',
            onRetry: () => ref.invalidate(subjectsProvider),
            builder: _buildGrid,
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: Gap.fabClearance + bottomInset),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<SubjectSummary> list) {
    if (list.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.school_outlined,
          title: 'Zatím žádné předměty',
          message:
              'Předmět drží karty s kontextem — knihy, témata, pojmy. '
              'AI je pak použije, když v hodině padne otázka. Předměty '
              'i rozvrh můžeš načíst ze screenshotu rozvrhu.',
          action: FilledButton.tonalIcon(
            onPressed: () => importTimetableFlow(context, ref),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Importovat rozvrh'),
          ),
        ),
      );
    }

    final firstPaint = _seen.isEmpty;
    final entering = <int, int>{};
    for (final s in list) {
      if (_seen.add(s.subject.id)) entering[s.subject.id] = entering.length;
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, i) {
          final summary = list[i];
          final order = entering[summary.subject.id];
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Entrance(
              enabled: order != null,
              delay: firstPaint && order != null
                  ? AppMotion.staggerDelay(order)
                  : Duration.zero,
              child: Pressable(child: _SubjectTile(summary: summary)),
            ),
          );
        }, childCount: list.length),
      ),
    );
  }
}

/// A compact neutral row; the subject colour is an identifier, not a surface.
class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.summary});

  final SubjectSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subject = summary.subject;
    final base = subjectColor(context, subject.colorIndex);
    final counts = [
      czechCount(summary.cardCount, 'karta', 'karty', 'karet'),
      czechCount(summary.lessonCount, 'hodina', 'hodiny', 'hodin'),
    ].join(' · ');

    return Card(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(Gap.radius),
        onTap: () =>
            Navigator.of(context).push(SubjectDetailScreen.route(subject.id)),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: base.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Gap.md),
                ),
                child: Icon(Icons.menu_book_outlined, color: base),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subject.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      counts,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
