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
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: Gap.md,
          crossAxisSpacing: Gap.md,
          childAspectRatio: 0.92,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final summary = list[i];
          final order = entering[summary.subject.id];
          return Entrance(
            enabled: order != null,
            delay: firstPaint && order != null
                ? AppMotion.staggerDelay(order)
                : Duration.zero,
            child: Pressable(child: _SubjectTile(summary: summary)),
          );
        },
      ),
    );
  }
}

/// A subject as a coloured tile: its initial large, the name, and what it
/// holds. The colour is the same one the subject's badge uses everywhere else,
/// so a lesson in the list and its subject here read as one thing.
class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.summary});

  final SubjectSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = summary.subject;
    final base = subjectColor(context, subject.colorIndex);
    final deep = Color.lerp(base, Colors.black, 0.28)!;
    const fg = Colors.white;
    final initial = subject.name.trim().isEmpty
        ? '?'
        : subject.name.trim()[0].toUpperCase();
    final counts = [
      czechCount(summary.cardCount, 'karta', 'karty', 'karet'),
      czechCount(summary.lessonCount, 'hodina', 'hodiny', 'hodin'),
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Gap.radius + 4),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, deep],
          ),
        ),
        child: InkWell(
          onTap: () =>
              Navigator.of(context).push(SubjectDetailScreen.route(subject.id)),
          child: Stack(
            children: [
              // A soft disc bleeding off the corner; decoration only.
              Positioned(
                right: -36,
                top: -36,
                child: ExcludeSemantics(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fg.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        initial,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: fg.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      counts,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
