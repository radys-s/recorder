import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/app_route.dart';
import '../../core/widgets/pressable.dart';
import '../../core/motion.dart';
import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/inset_group.dart';
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
        child: GradientFab(
          onPressed: _create,
          icon: Icons.add,
          label: 'Nový předmět',
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
            style: tonalButtonStyle(context),
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

    // One inset group rather than a card per subject: the rows share a
    // surface, and the subject colour lives in the gradient tile only.
    return SliverList(
      delegate: SliverChildListDelegate([
        InsetGroup(
          label: czechCount(list.length, 'předmět', 'předměty', 'předmětů'),
          dividerIndent: Gap.lg + _SubjectRow.slot,
          children: [
            for (final summary in list)
              Entrance(
                key: ValueKey(summary.subject.id),
                enabled: entering[summary.subject.id] != null,
                delay: firstPaint && entering[summary.subject.id] != null
                    ? AppMotion.staggerDelay(entering[summary.subject.id]!)
                    : Duration.zero,
                child: _SubjectRow(summary: summary),
              ),
          ],
        ),
      ]),
    );
  }
}

/// A subject as a row: its colour as a gradient tile, name, and what it holds.
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.summary});

  final SubjectSummary summary;

  static const slot = 52.0;

  @override
  Widget build(BuildContext context) {
    final subject = summary.subject;
    final counts = [
      czechCount(summary.cardCount, 'karta', 'karty', 'karet'),
      czechCount(summary.lessonCount, 'hodina', 'hodiny', 'hodin'),
    ].join(' · ');

    return ListRow(
      leadingSlot: slot,
      leading: HeroMode(
        enabled:
            !reducedMotion(context) && TickerMode.valuesOf(context).enabled,
        child: Hero(
          tag: subjectHeroTag(subject.id),
          child: GradientIconTile(
            icon: Icons.menu_book_rounded,
            color: subjectColor(context, subject.colorIndex),
          ),
        ),
      ),
      title: subject.name,
      subtitle: counts,
      onTap: () => Navigator.of(context)
          .push(SubjectDetailScreen.route(subject.id, heroSubject: subject)),
    );
  }
}

/// The extended action button on a lit accent gradient. Still a
/// [FloatingActionButton], so the Scaffold places and animates it as usual.
class GradientFab extends StatelessWidget {
  const GradientFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final radius = BorderRadius.circular(Gap.lg);
    return Pressable(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: accent.fillGradient,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: accent.fill.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: Colors.transparent,
          foregroundColor: accent.onFill,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}
