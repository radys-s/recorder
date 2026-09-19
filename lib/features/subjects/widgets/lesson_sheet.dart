import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';
import '../subject_actions.dart';
import '../subjects_providers.dart';
import '../timetable.dart';
import 'subject_badge.dart';

/// What a lesson is about: its subject, the cards pinned for it, and rules for
/// this lesson only.
typedef LessonSetup = ({int? subjectId, List<int> cardIds, String? rules});

const LessonSetup _noLesson = (subjectId: null, cardIds: [], rules: null);

/// The sheet shown before recording starts. Resolves to null when cancelled.
///
/// Skipped — resolving straight to a plain recording — while there are no
/// subjects at all: a sheet whose only choice is „Bez předmětu" would be a tap
/// between the student and the record button for nothing.
Future<LessonSetup?> showStartRecordingSheet(
  BuildContext context,
  WidgetRef ref, {
  DateTime? now,
  int? preselectSubjectId,
}) async {
  final dao = ref.read(subjectsDaoProvider);
  final subjects = await dao.allSubjects();
  if (subjects.isEmpty || !context.mounted) return _noLesson;

  // The subject the timetable has on right now, else the subject of the last
  // recording — and the cards that subject pinned last time, so starting is
  // one tap when nothing changed.
  bool known(int? id) => id != null && subjects.any((s) => s.subject.id == id);
  final scheduled = pickSubjectForNow(
    await dao.allSlots(),
    now ?? DateTime.now(),
  );
  final last = await dao.lastUsedSubjectId();
  // A tapped reminder named the lesson outright, so it wins over both guesses.
  final subjectId = known(preselectSubjectId)
      ? preselectSubjectId
      : known(scheduled)
      ? scheduled
      : known(last)
      ? last
      : null;
  final cardIds = subjectId == null
      ? const <int>[]
      : await dao.lastPinnedCardIds(subjectId);
  if (!context.mounted) return null;

  return showModalBottomSheet<LessonSetup>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LessonSheet(
      title: 'Nové nahrávání',
      confirmLabel: 'Začít',
      confirmIcon: Icons.mic,
      initial: (subjectId: subjectId, cardIds: cardIds, rules: null),
      proposeLastCards: true,
    ),
  );
}

/// Changes an existing lesson's subject, pinned cards and rules.
Future<void> showLessonSheet(
  BuildContext context,
  WidgetRef ref,
  Meeting meeting,
) async {
  final dao = ref.read(subjectsDaoProvider);
  final pinned = await dao.pinnedCardIds(meeting.id);
  if (!context.mounted) return;

  final result = await showModalBottomSheet<LessonSetup>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LessonSheet(
      title: 'Předmět a karty',
      confirmLabel: 'Uložit',
      confirmIcon: Icons.check,
      initial: (
        subjectId: meeting.subjectId,
        cardIds: pinned,
        rules: meeting.rules,
      ),
      proposeLastCards: false,
    ),
  );
  if (result == null) return;

  await dao.setMeetingSubject(meeting.id, result.subjectId);
  await dao.pinCards(
    meeting.id,
    result.subjectId == null ? const [] : result.cardIds,
  );
  await dao.setMeetingRules(meeting.id, result.rules);
}

class _LessonSheet extends ConsumerStatefulWidget {
  const _LessonSheet({
    required this.title,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.initial,
    required this.proposeLastCards,
  });

  final String title;
  final String confirmLabel;
  final IconData confirmIcon;
  final LessonSetup initial;

  /// Whether picking a subject preselects the cards of its last lesson.
  final bool proposeLastCards;

  @override
  ConsumerState<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends ConsumerState<_LessonSheet> {
  late int? _subjectId = widget.initial.subjectId;
  late final Set<int> _cardIds = {...widget.initial.cardIds};
  late final _rules = TextEditingController(text: widget.initial.rules ?? '');
  late bool _showRules = (widget.initial.rules ?? '').isNotEmpty;

  @override
  void dispose() {
    _rules.dispose();
    super.dispose();
  }

  Future<void> _pickSubject(int? id) async {
    if (id == _subjectId) return;
    setState(() {
      _subjectId = id;
      _cardIds.clear();
    });
    if (id == null || !widget.proposeLastCards) return;
    final proposed = await ref.read(subjectsDaoProvider).lastPinnedCardIds(id);
    if (mounted && _subjectId == id) setState(() => _cardIds.addAll(proposed));
  }

  void _confirm() {
    final rules = _rules.text.trim();
    Navigator.of(context).pop((
      subjectId: _subjectId,
      cardIds: _subjectId == null ? const <int>[] : _cardIds.toList(),
      rules: rules.isEmpty ? null : rules,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final subjectId = _subjectId;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: Gap.lg),
              Text('Předmět', style: theme.textTheme.titleSmall),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Bez předmětu'),
                    selected: subjectId == null,
                    onSelected: (_) => _pickSubject(null),
                  ),
                  for (final s in subjects)
                    ChoiceChip(
                      avatar: SubjectDot(
                        color: subjectColor(context, s.subject.colorIndex),
                      ),
                      label: Text(s.subject.name),
                      selected: subjectId == s.subject.id,
                      onSelected: (_) => _pickSubject(s.subject.id),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Nový předmět'),
                    onPressed: () async {
                      final id = await createSubjectFlow(context, ref);
                      if (id != null) await _pickSubject(id);
                    },
                  ),
                ],
              ),
              if (subjectId != null) ...[
                const SizedBox(height: Gap.lg),
                Text('Připnuté karty', style: theme.textTheme.titleSmall),
                const SizedBox(height: Gap.xs),
                Text(
                  'AI je má v hodině vždy po ruce. Ostatní karty předmětu '
                  'použije, když na ně řeč přijde.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                _CardChips(
                  subjectId: subjectId,
                  selected: _cardIds,
                  onToggle: (id, on) => setState(
                    () => on ? _cardIds.add(id) : _cardIds.remove(id),
                  ),
                ),
              ],
              const SizedBox(height: Gap.md),
              if (_showRules)
                TextField(
                  controller: _rules,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Pravidla pro tuto hodinu',
                    hintText: 'Třeba: odpovídej jednou větou',
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showRules = true),
                    icon: const Icon(Icons.rule, size: 18),
                    label: const Text('Pravidla pro tuto hodinu'),
                  ),
                ),
              const SizedBox(height: Gap.lg),
              FilledButton.icon(
                onPressed: _confirm,
                icon: Icon(widget.confirmIcon),
                label: Text(widget.confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardChips extends ConsumerWidget {
  const _CardChips({
    required this.subjectId,
    required this.selected,
    required this.onToggle,
  });

  final int subjectId;
  final Set<int> selected;
  final void Function(int id, bool on) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(subjectCardsProvider(subjectId)).valueOrNull;
    if (cards == null) return const SizedBox(height: 32);
    if (cards.isEmpty) {
      return Text(
        'Tento předmět zatím nemá karty. Přidáš je v záložce Předměty.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final card in cards)
          FilterChip(
            label: Text(card.title, overflow: TextOverflow.ellipsis),
            selected: selected.contains(card.id),
            onSelected: (on) => onToggle(card.id, on),
          ),
      ],
    );
  }
}
