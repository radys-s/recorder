import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/motion.dart';
import '../../core/spacing.dart';
import '../../core/widgets/count_up.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/flip_card.dart';
import '../../core/widgets/inset_group.dart';
import '../../core/widgets/pop_in.dart';
import '../../core/widgets/pressable.dart';
import '../../data/db/app_database.dart';
import '../../learning/scheduler.dart';
import '../../learning/study_flow.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../subjects/subjects_providers.dart';
import 'study_next_steps.dart';
import 'study_providers.dart';

/// One review session: today's due cards, one at a time, question first.
///
/// A card graded „Znovu" goes to the back of this session's queue, so it
/// comes round again before the session ends — that is what the ten-minute
/// relearn step means in practice.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.subjectId, this.meetingId});

  /// Null reviews every subject.
  final int? subjectId;

  /// Only the cards one lesson's výpisky produced.
  final int? meetingId;

  static Route<void> route({int? subjectId, int? meetingId}) =>
      MaterialPageRoute(
        builder: (_) =>
            ReviewScreen(subjectId: subjectId, meetingId: meetingId),
      );

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<StudyCard>? _queue;
  Map<int, String> _subjects = const {};

  /// When each source lesson happened, for the card's provenance line.
  Map<int, DateTime> _lessonDates = const {};
  Object? _error;
  var _index = 0;
  var _revealed = false;
  var _busy = false;
  final _tally = {for (final g in ReviewGrade.values) g: 0};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = ref.read(studyClockProvider)();
      final cards = await ref
          .read(studyCardsDaoProvider)
          .dueCards(
            now,
            subjectId: widget.subjectId,
            meetingId: widget.meetingId,
          );
      final subjects = await ref.read(subjectsDaoProvider).allSubjects();
      final meetings = ref.read(appDatabaseProvider).meetingsDao;
      final dates = <int, DateTime>{};
      for (final id in {
        for (final c in cards)
          if (c.meetingId != null) c.meetingId!,
      }) {
        final m = await meetings.watchMeetingByIdOnce(id);
        if (m != null) dates[id] = m.createdAt;
      }
      if (!mounted) return;
      setState(() {
        _queue = cards;
        _lessonDates = dates;
        _subjects = {for (final s in subjects) s.subject.id: s.subject.name};
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _reveal() {
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
  }

  ReviewState _stateOf(StudyCard c) => ReviewState(
    ease: c.ease,
    intervalDays: c.intervalDays,
    reps: c.reps,
    lapses: c.lapses,
  );

  Future<void> _grade(ReviewGrade grade) async {
    final queue = _queue;
    if (queue == null || _busy || _index >= queue.length) return;
    final card = queue[_index];
    final outcome = schedule(
      _stateOf(card),
      grade,
      ref.read(studyClockProvider)(),
    );
    setState(() => _busy = true);
    try {
      await ref.read(studyCardsDaoProvider).applyReview(card.id, outcome);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hodnocení se nepodařilo uložit.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _tally[grade] = _tally[grade]! + 1;
      if (grade == ReviewGrade.again) {
        queue.add(
          card.copyWith(
            ease: outcome.state.ease,
            intervalDays: outcome.state.intervalDays,
            reps: outcome.state.reps,
            lapses: outcome.state.lapses,
            dueAt: outcome.dueAt,
          ),
        );
      }
      _index++;
      _revealed = false;
    });
    if (_index >= queue.length) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    final title = widget.meetingId != null
        ? 'Opakování hodiny'
        : widget.subjectId == null
        ? 'Opakování'
        : _subjects[widget.subjectId] ?? 'Opakování';

    Widget body;
    if (_error != null) {
      body = const EmptyState(
        icon: Icons.error_outline,
        title: 'Kartičky se nepodařilo načíst',
      );
    } else if (queue == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (queue.isEmpty) {
      body = _Finished(
        tally: _tally,
        subjectId: widget.subjectId,
        meetingId: widget.meetingId,
        nothingDue: true,
      );
    } else if (_index >= queue.length) {
      // One subject, when the session was about one: the next steps need it.
      final subjectIds = {for (final c in queue) c.subjectId};
      body = _Finished(
        tally: _tally,
        subjectId:
            widget.subjectId ??
            (subjectIds.length == 1 ? subjectIds.first : null),
        meetingId: widget.meetingId,
        nothingDue: false,
      );
    } else {
      body = _ReviewBody(
        card: queue[_index],
        subjectName: widget.subjectId == null
            ? _subjects[queue[_index].subjectId]
            : null,
        provenance: studyCardProvenance(
          queue[_index],
          lessonDate: _lessonDates[queue[_index].meetingId],
        ),
        onOpenLesson: _lessonDates.containsKey(queue[_index].meetingId)
            ? () =>
                  Navigator.of(context)
                      .push(MeetingDetailScreen.route(queue[_index].meetingId!))
            : null,
        position: _index + 1,
        total: queue.length,
        revealed: _revealed,
        busy: _busy,
        stateOf: _stateOf,
        now: ref.read(studyClockProvider),
        onReveal: _reveal,
        onGrade: _grade,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: queue == null || queue.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: _index / queue.length),
                  duration: reducedMotion(context)
                      ? Duration.zero
                      : AppDuration.base,
                  curve: AppCurve.standard,
                  builder: (_, value, _) =>
                      LinearProgressIndicator(value: value, minHeight: 3),
                ),
              ),
      ),
      body: SafeArea(child: body),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.card,
    required this.subjectName,
    required this.provenance,
    required this.onOpenLesson,
    required this.position,
    required this.total,
    required this.revealed,
    required this.busy,
    required this.stateOf,
    required this.now,
    required this.onReveal,
    required this.onGrade,
  });

  final StudyCard card;
  final String? subjectName;

  /// Where the card came from and that a model wrote it.
  final String provenance;

  /// Opens the source lesson; null when the card has none any more.
  final VoidCallback? onOpenLesson;
  final int position;
  final int total;
  final bool revealed;
  final bool busy;
  final ReviewState Function(StudyCard) stateOf;
  final DateTime Function() now;
  final VoidCallback onReveal;
  final ValueChanged<ReviewGrade> onGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final at = now();
    final meta = [
      ?subjectName,
      card.source.label,
      '$position / $total',
    ].join(' · ');

    final reduced = reducedMotion(context);
    final outline = context.accent.hairline(scheme.outlineVariant);
    final radius = BorderRadius.circular(InsetGroup.radius);

    // The same card with and without the answer. The flip swaps between them,
    // and the back keeps the question on top, so the student still sees what
    // was asked.
    Widget face({required bool back}) => GradientOutline(
      gradient: outline,
      borderRadius: radius,
      width: 0.8,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                meta.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Gap.md),
              Text(
                card.front,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              if (back) ...[
                const SizedBox(height: Gap.lg),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: Gap.lg),
                SelectableText(
                  card.back,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: Gap.lg),
                Text(
                  provenance,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (onOpenLesson != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onOpenLesson,
                      icon: const Icon(Icons.north_east_rounded, size: 18),
                      label: const Text('Otevřít hodinu'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    // Slides the next card in from the right while the old one leaves to the
    // left; keyed by position so a card graded „Znovu" that comes round again
    // still gets its own entrance.
    final cardKey = ValueKey('card$position');
    Widget slide(Widget child, Animation<double> a) {
      final incoming = child.key == cardKey;
      return FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(incoming ? 0.12 : -0.12, 0),
            end: Offset.zero,
          ).animate(a),
          child: child,
        ),
      );
    }

    final bottom = revealed
        ? Row(
            key: const ValueKey('grades'),
            children: [
              for (final g in ReviewGrade.values) ...[
                if (g != ReviewGrade.again) const SizedBox(width: Gap.sm),
                Expanded(
                  child: Pressable(
                    child: _GradeButton(
                      grade: g,
                      next: describeNextReview(
                        schedule(stateOf(card), g, at),
                        at,
                      ),
                      onPressed: busy ? null : () => onGrade(g),
                    ),
                  ),
                ),
              ],
            ],
          )
        : Pressable(
            key: const ValueKey('reveal'),
            child: FilledButton(
              onPressed: onReveal,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Ukázat odpověď'),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
            child: GestureDetector(
              onTap: revealed ? null : onReveal,
              child: AnimatedSwitcher(
                duration: reduced ? Duration.zero : AppDuration.base,
                switchInCurve: AppCurve.standard,
                switchOutCurve: AppCurve.standard,
                transitionBuilder: slide,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: SizedBox(
                  key: cardKey,
                  width: double.infinity,
                  child: AnimatedSize(
                    duration: reduced ? Duration.zero : AppDuration.base,
                    curve: AppCurve.standard,
                    alignment: Alignment.topCenter,
                    child: FlipCard(
                      front: face(back: false),
                      back: face(back: true),
                      flipped: revealed,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: AnimatedSize(
            duration: reduced ? Duration.zero : AppDuration.quick,
            curve: AppCurve.standard,
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : AppDuration.quick,
              transitionBuilder: (child, a) =>
                  FadeTransition(opacity: a, child: child),
              child: bottom,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.grade,
    required this.next,
    required this.onPressed,
  });

  final ReviewGrade grade;
  final String next;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(grade.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          next,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
    final padding = const EdgeInsets.symmetric(
      horizontal: Gap.xs,
      vertical: Gap.sm,
    );
    final size = const Size.fromHeight(56);
    return Semantics(
      button: true,
      label: '${grade.label}, další opakování $next',
      excludeSemantics: true,
      child: grade == ReviewGrade.good
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: padding,
                minimumSize: size,
              ),
              child: label,
            )
          : FilledButton(
              onPressed: onPressed,
              style: tonalButtonStyle(context).copyWith(
                padding: WidgetStatePropertyAll(padding),
                minimumSize: WidgetStatePropertyAll(size),
                foregroundColor: grade == ReviewGrade.again
                    ? WidgetStatePropertyAll(theme.colorScheme.error)
                    : null,
              ),
              child: label,
            ),
    );
  }
}

/// One grade's share of the session: a bar that grows to its length.
class _TallyBar extends StatelessWidget {
  const _TallyBar({
    required this.label,
    required this.count,
    required this.share,
    required this.color,
  });

  final String label;
  final int count;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = reducedMotion(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 10,
                color: theme.colorScheme.surfaceContainerHighest,
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: share),
                  duration: reduced ? Duration.zero : AppDuration.slow,
                  curve: AppCurve.standard,
                  builder: (_, value, _) => FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Finished extends ConsumerWidget {
  const _Finished({
    required this.tally,
    required this.subjectId,
    required this.meetingId,
    required this.nothingDue,
  });

  final Map<ReviewGrade, int> tally;
  final int? subjectId;
  final int? meetingId;

  /// The session had no cards at all, rather than ending after some.
  final bool nothingDue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reviewed = tally.values.fold(0, (a, b) => a + b);
    final peak = tally.values.fold(0, (a, b) => a > b ? a : b);
    final dueLeft = subjectId == null
        ? 0
        : ref.watch(dueStudyCountProvider(subjectId)).valueOrNull ?? 0;

    final title = nothingDue ? 'Dnes není co opakovat' : 'Hotovo na dnešek';
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final gradeColors = {
      ReviewGrade.again: scheme.error,
      ReviewGrade.hard: scheme.tertiary,
      ReviewGrade.good: scheme.primary,
      ReviewGrade.easy: scheme.secondary,
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: [
        const SizedBox(height: Gap.xl),
        Center(
          child: PopIn(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: context.accent.softGradient(strength: 1.4),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: .35),
                  width: 1.2,
                ),
              ),
              child: Icon(
                nothingDue ? Icons.style_outlined : Icons.check_rounded,
                size: 44,
                color: scheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Gap.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          child: nothingDue
              ? Text(
                  'Kartičky vznikají z výpisků hodin. Každá se vrátí, '
                  'až na ni podle plánu přijde řada.',
                  textAlign: TextAlign.center,
                  style: muted,
                )
              : Center(
                  child: CountUp(
                    value: reviewed,
                    style: muted,
                    format: (v) =>
                        czechCount(v, 'hodnocení', 'hodnocení', 'hodnocení'),
                  ),
                ),
        ),
        if (!nothingDue && peak > 0) ...[
          const SizedBox(height: Gap.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
            child: Column(
              children: [
                for (final g in ReviewGrade.values)
                  if (tally[g]! > 0)
                    _TallyBar(
                      label: g.label,
                      count: tally[g]!,
                      share: tally[g]! / peak,
                      color: gradeColors[g]!,
                    ),
              ],
            ),
          ),
        ],
        NextDueLine(subjectId: subjectId, meetingId: meetingId),
        if (subjectId != null)
          NextStepsGroup(
            steps: subjectNextSteps(
              context,
              subjectId: subjectId!,
              dueLeft: dueLeft,
            ),
          ),
        const SizedBox(height: Gap.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Zavřít'),
          ),
        ),
      ],
    );
  }
}
