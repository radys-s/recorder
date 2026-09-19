import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/course_overview.dart';
import '../../../core/pending_deletions.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/db/app_database.dart';
import '../../meeting_detail/meeting_detail_screen.dart';
import '../../notes_library/saved_note_screen.dart';
import '../subjects_providers.dart';
import '../syllabus_import_screen.dart' show monthRangeLabel;

/// „Přehled" on a subject: the thematic plan as a timeline with the lessons
/// that covered each topic, and „Shrnutí předmětu" over all the výpisky.
class SubjectOverview extends ConsumerWidget {
  const SubjectOverview({
    super.key,
    required this.subjectId,
    required this.onOpenSettings,
    this.now,
  });

  final int subjectId;

  /// Where the plan is added — the subject's Nastavení tab.
  final VoidCallback onOpenSettings;

  /// Injectable for tests; what is "now" in the plan depends on the date.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pendingIdsProvider(DeletionKind.meeting));
    final topics = ref.watch(subjectTopicsProvider(subjectId));
    final lessons = ref.watch(subjectLessonsProvider(subjectId));
    final withNotes = ref.watch(meetingIdsWithNotesProvider);

    final failed = [topics, lessons, withNotes].where((v) => v.hasError);
    final (t, l, n) =
        (topics.valueOrNull, lessons.valueOrNull, withNotes.valueOrNull);
    final AsyncValue<_OverviewData> data = t != null && l != null && n != null
        ? AsyncValue.data((
            topics: t,
            lessons: [
              for (final m in l)
                if (!hidden.contains(m.id)) m,
            ],
            withNotes: n,
          ))
        : failed.isNotEmpty
        ? AsyncValue.error(failed.first.error!, failed.first.stackTrace!)
        : const AsyncValue.loading();

    return AsyncView(
      value: data,
      message: 'Přehled se nepodařilo načíst.',
      onRetry: () {
        ref.invalidate(subjectTopicsProvider(subjectId));
        ref.invalidate(subjectLessonsProvider(subjectId));
        ref.invalidate(meetingIdsWithNotesProvider);
      },
      builder: (d) {
        final overview = courseOverview(
          topics: d.topics,
          lessons: d.lessons,
          now: now ?? DateTime.now(),
        );
        final noted = d.lessons.where((m) => d.withNotes.contains(m.id)).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
          children: [
            _Progress(overview: overview, onOpenSettings: onOpenSettings),
            const SizedBox(height: Gap.lg),
            _SummaryBlock(
              subjectId: subjectId,
              lessons: d.lessons.length,
              withNotes: noted,
            ),
            if (overview.topics.isNotEmpty) ...[
              const SizedBox(height: Gap.xl),
              Text(
                'Tematický plán',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: Gap.sm),
              for (var i = 0; i < overview.topics.length; i++)
                _TopicRow(
                  topic: overview.topics[i],
                  first: i == 0,
                  last: i == overview.topics.length - 1,
                ),
            ],
          ],
        );
      },
    );
  }
}

typedef _OverviewData = ({
  List<SyllabusTopic> topics,
  List<Meeting> lessons,
  Set<int> withNotes,
});

/// The colour a status is drawn in, on the bar and on the timeline rail.
Color coverageColor(ColorScheme scheme, TopicCoverage coverage) =>
    switch (coverage) {
      TopicCoverage.covered => scheme.primary,
      TopicCoverage.current => scheme.tertiary,
      TopicCoverage.missed => scheme.error,
      TopicCoverage.upcoming => scheme.surfaceContainerHighest,
      TopicCoverage.beforeRecording => scheme.outlineVariant,
    };

// --------------------------------------------------------------- progress

class _Progress extends StatelessWidget {
  const _Progress({required this.overview, required this.onOpenSettings});

  final CourseOverview overview;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (overview.topics.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Zatím bez plánu', style: theme.textTheme.titleMedium),
              const SizedBox(height: Gap.xs),
              Text(
                'S tematickým plánem tu uvidíš, co už hodiny probraly, co '
                'chybí a co tě čeká.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.md),
              FilledButton.tonalIcon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.format_list_numbered),
                label: const Text('Přidat plán'),
              ),
            ],
          ),
        ),
      );
    }

    final covered = overview.count(TopicCoverage.covered);
    final missed = overview.count(TopicCoverage.missed);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Probráno $covered z ${overview.total}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: Gap.md),
            Semantics(
              label: 'Probráno $covered z ${overview.total} témat',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        for (var i = 0; i < overview.topics.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(
                            child: ColoredBox(
                              color: coverageColor(
                                scheme,
                                overview.topics[i].coverage,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (missed > 0) ...[
              const SizedBox(height: Gap.md),
              StatusChip(
                icon: Icons.error_outline,
                label: 'Chybí záznam: $missed',
                tone: ChipTone.alert,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- summary

class _SummaryBlock extends ConsumerStatefulWidget {
  const _SummaryBlock({
    required this.subjectId,
    required this.lessons,
    required this.withNotes,
  });

  final int subjectId;
  final int lessons;
  final int withNotes;

  @override
  ConsumerState<_SummaryBlock> createState() => _SummaryBlockState();
}

class _SummaryBlockState extends ConsumerState<_SummaryBlock> {
  bool _busy = false;

  Future<void> _summarize() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final result = await ref
        .read(subjectSummaryServiceProvider)
        .summarize(widget.subjectId);
    if (mounted) setState(() => _busy = false);

    final noteId = result.noteId;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        noteId == null
            ? SnackBar(content: Text(result.error ?? 'Shrnutí se nepodařilo.'))
            : SnackBar(
                content: const Text('Shrnutí je uložené v poznámkách.'),
                action: SnackBarAction(
                  label: 'Otevřít',
                  onPressed: () => navigator.push(SavedNoteScreen.route(noteId)),
                ),
              ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final missing = widget.lessons - widget.withNotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: _busy || widget.withNotes == 0 ? null : _summarize,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_outlined),
          label: Text(_busy ? 'Píšu shrnutí…' : 'Shrnutí předmětu'),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          widget.withNotes == 0
              ? 'Nejdřív vytvoř výpisky u hodin — shrnutí vychází z nich.'
              : 'Co jsme probrali, co podle plánu chybí a na co se zaměřit '
                    'před testem. Uloží se do poznámek předmětu.',
          style: muted,
        ),
        if (widget.withNotes > 0 && missing > 0) ...[
          const SizedBox(height: Gap.xs),
          Text(
            '${_lessonsWithout(missing)} bez výpisků — do shrnutí se '
            'nezapočítají.',
            style: muted,
          ),
        ],
      ],
    );
  }
}

/// „1 hodina", „2 hodiny", „5 hodin" — `czechCount` already puts the number
/// in front.
String _lessonsWithout(int n) => czechCount(n, 'hodina', 'hodiny', 'hodin');

// --------------------------------------------------------------- timeline

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.first,
    required this.last,
  });

  final TopicOverview topic;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = coverageColor(scheme, topic.coverage);
    final months = monthRangeLabel(topic.topic.monthFrom, topic.topic.monthTo);
    final faded = topic.coverage == TopicCoverage.upcoming ||
        topic.coverage == TopicCoverage.beforeRecording;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: Gap.lg,
                  color: first ? Colors.transparent : scheme.outlineVariant,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: faded ? scheme.surface : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: faded ? scheme.outline : color,
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last ? Colors.transparent : scheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.topic.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: topic.isCurrent ? FontWeight.w700 : null,
                      color: faded ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: Gap.xs),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(
                        icon: _icon(topic.coverage),
                        label: coverageLabel(topic.coverage),
                        tone: switch (topic.coverage) {
                          TopicCoverage.missed => ChipTone.alert,
                          TopicCoverage.covered ||
                          TopicCoverage.current => ChipTone.progress,
                          _ => ChipTone.neutral,
                        },
                      ),
                      if (topic.isCurrent &&
                          topic.coverage != TopicCoverage.current)
                        const StatusChip(
                          icon: Icons.play_circle_outline,
                          label: 'Teď',
                          tone: ChipTone.progress,
                        ),
                      if (months != null)
                        Text(
                          months,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (topic.lessons.isNotEmpty) ...[
                    const SizedBox(height: Gap.sm),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        for (final lesson in topic.lessons)
                          ActionChip(
                            avatar: const Icon(Icons.mic_none, size: 16),
                            label: Text(_lessonDate(lesson.createdAt)),
                            tooltip: 'Otevřít hodinu',
                            onPressed: () => Navigator.of(context)
                                .push(MeetingDetailScreen.route(lesson.id)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(TopicCoverage coverage) => switch (coverage) {
    TopicCoverage.covered => Icons.check_circle_outline,
    TopicCoverage.current => Icons.play_circle_outline,
    TopicCoverage.missed => Icons.error_outline,
    TopicCoverage.upcoming => Icons.schedule,
    TopicCoverage.beforeRecording => Icons.history,
  };
}

String _lessonDate(DateTime d) => '${d.day}. ${d.month}.';
