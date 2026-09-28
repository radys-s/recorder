import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/motion.dart';
import '../../core/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/inset_group.dart';
import '../../data/db/app_database.dart';
import '../../learning/scheduler.dart';
import '../subjects/subjects_providers.dart';
import 'study_providers.dart';

/// One review session: today's due cards, one at a time, question first.
///
/// A card graded „Znovu" goes to the back of this session's queue, so it
/// comes round again before the session ends — that is what the ten-minute
/// relearn step means in practice.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.subjectId});

  /// Null reviews every subject.
  final int? subjectId;

  static Route<void> route({int? subjectId}) =>
      MaterialPageRoute(builder: (_) => ReviewScreen(subjectId: subjectId));

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<StudyCard>? _queue;
  Map<int, String> _subjects = const {};
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
          .dueCards(now, subjectId: widget.subjectId);
      final subjects = await ref.read(subjectsDaoProvider).allSubjects();
      if (!mounted) return;
      setState(() {
        _queue = cards;
        _subjects = {for (final s in subjects) s.subject.id: s.subject.name};
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
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
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    final title = widget.subjectId == null
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
      body = EmptyState(
        icon: Icons.style_outlined,
        title: 'Dnes není co opakovat',
        message:
            'Kartičky vznikají z výpisků hodin. Každá se vrátí, '
            'až na ni podle plánu přijde řada.',
        action: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zavřít'),
        ),
      );
    } else if (_index >= queue.length) {
      body = _Finished(tally: _tally);
    } else {
      body = _ReviewBody(
        card: queue[_index],
        subjectName: widget.subjectId == null
            ? _subjects[queue[_index].subjectId]
            : null,
        position: _index + 1,
        total: queue.length,
        revealed: _revealed,
        busy: _busy,
        stateOf: _stateOf,
        now: ref.read(studyClockProvider),
        onReveal: () => setState(() => _revealed = true),
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
                child: LinearProgressIndicator(
                  value: _index / queue.length,
                  minHeight: 3,
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

    final answer = revealed
        ? Column(
            key: const ValueKey('back'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Gap.lg),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: Gap.lg),
              SelectableText(
                card.back,
                style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
              ),
            ],
          )
        : const SizedBox(key: ValueKey('front'), width: double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
            child: GestureDetector(
              onTap: revealed ? null : onReveal,
              child: GradientOutline(
                gradient: context.accent.hairline(scheme.outlineVariant),
                borderRadius: BorderRadius.circular(InsetGroup.radius),
                width: 0.8,
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(InsetGroup.radius),
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
                        AnimatedSwitcher(
                          duration: reducedMotion(context)
                              ? Duration.zero
                              : AppDuration.quick,
                          switchInCurve: AppCurve.standard,
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SizeTransition(
                              sizeFactor: a,
                              alignment: Alignment.topCenter,
                              child: child,
                            ),
                          ),
                          child: answer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: revealed
              ? Row(
                  children: [
                    for (final g in ReviewGrade.values) ...[
                      if (g != ReviewGrade.again) const SizedBox(width: Gap.sm),
                      Expanded(
                        child: _GradeButton(
                          grade: g,
                          next: describeNextReview(
                            schedule(stateOf(card), g, at),
                            at,
                          ),
                          onPressed: busy ? null : () => onGrade(g),
                        ),
                      ),
                    ],
                  ],
                )
              : FilledButton(
                  onPressed: onReveal,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Ukázat odpověď'),
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

class _Finished extends StatelessWidget {
  const _Finished({required this.tally});

  final Map<ReviewGrade, int> tally;

  @override
  Widget build(BuildContext context) {
    final reviewed = tally.values.fold(0, (a, b) => a + b);
    final parts = [
      for (final g in ReviewGrade.values)
        if (tally[g]! > 0) '${g.label}: ${tally[g]}',
    ].join(' · ');
    return EmptyState(
      icon: Icons.check_circle_outline,
      title: 'Hotovo na dnešek',
      message:
          '${czechCount(reviewed, 'hodnocení', 'hodnocení', 'hodnocení')}'
          '${parts.isEmpty ? '' : '\n$parts'}',
      action: FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Zavřít'),
      ),
    );
  }
}
