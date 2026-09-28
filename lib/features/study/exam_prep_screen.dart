import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/inset_group.dart';
import '../../core/widgets/notes_text.dart';
import '../../learning/exam_prep.dart';
import '../legal/ai_disclaimer.dart';
import '../notes_library/saved_note_screen.dart';
import '../subjects/subjects_providers.dart';

enum _Stage { pick, loading, summary, quiz, result }

/// „Před testem": pick topics, read what to know, take a ten-question quiz,
/// and turn the mistakes into study cards.
class ExamPrepScreen extends ConsumerStatefulWidget {
  const ExamPrepScreen({super.key, required this.subjectId});

  final int subjectId;

  static Route<void> route(int subjectId) =>
      MaterialPageRoute(builder: (_) => ExamPrepScreen(subjectId: subjectId));

  @override
  ConsumerState<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends ConsumerState<ExamPrepScreen> {
  var _stage = _Stage.pick;
  final _topicIds = <int>{};
  String? _error;
  ExamPrep? _prep;
  final _answers = <ExamAnswer>[];
  int? _picked;
  var _revealed = false;
  int? _noteId;
  int? _added;

  ExamQuestion get _current => _prep!.questions[_answers.length];

  Future<void> _prepare() async {
    setState(() {
      _stage = _Stage.loading;
      _error = null;
    });
    final result = await ref
        .read(examPrepServiceProvider)
        .prepare(widget.subjectId, topicIds: _topicIds);
    if (!mounted) return;
    setState(() {
      _prep = result.prep;
      _error = result.error;
      _stage = result.prep == null ? _Stage.pick : _Stage.summary;
    });
  }

  void _answer(bool correct, {String? given}) {
    HapticFeedback.selectionClick();
    _answers.add(ExamAnswer(_current, correct: correct, given: given));
    _picked = null;
    _revealed = false;
    if (_answers.length < _prep!.questions.length) {
      setState(() {});
      return;
    }
    setState(() => _stage = _Stage.result);
    _save();
  }

  Future<void> _save() async {
    try {
      final id = await ref
          .read(examPrepServiceProvider)
          .saveResult(widget.subjectId, _prep!, _answers);
      if (mounted) setState(() => _noteId = id);
    } catch (_) {
      // The quiz is still shown; only the saved copy is missing.
    }
  }

  Future<void> _addMistakes() async {
    try {
      final n = await ref
          .read(examPrepServiceProvider)
          .addMistakes(widget.subjectId, _answers);
      if (mounted) setState(() => _added = n);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kartičky se nepodařilo přidat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prep = _prep;
    final total = prep?.questions.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Před testem'),
        bottom: _stage == _Stage.quiz
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _answers.length / total,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.pick => _pick(context),
          _Stage.loading => const EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: 'Skládám test',
            message: 'Čtu výpisky a připravuji shrnutí a otázky.',
            action: CircularProgressIndicator(),
          ),
          _Stage.summary => _summary(context, prep!),
          _Stage.quiz => _quiz(context),
          _Stage.result => _result(context),
        },
      ),
    );
  }

  Widget _pick(BuildContext context) {
    final theme = Theme.of(context);
    final topics =
        ref.watch(subjectTopicsProvider(widget.subjectId)).valueOrNull ??
        const [];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: Text(
            'Z výpisků hodin připravím, co umět, a deset otázek na '
            'vyzkoušení. Chyby můžeš přidat do opakování.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        if (topics.isNotEmpty)
          InsetGroup(
            label: 'Témata testu',
            children: [
              for (final t in topics)
                CheckboxListTile(
                  value: _topicIds.contains(t.id),
                  title: Text(t.title),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _topicIds.add(t.id);
                    } else {
                      _topicIds.remove(t.id);
                    }
                  }),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: Text(
            _topicIds.isEmpty
                ? 'Bez výběru témat projdu celé dosavadní učivo.'
                : 'Jen hodiny k vybraným tématům.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: FilledButton.icon(
            onPressed: _prepare,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Připravit test'),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, ExamPrep prep) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Gap.lg),
            children: [
              Text('Co umět', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Gap.md),
              NotesText(
                content: prep.summary.isEmpty
                    ? '- Shrnutí chybí, rovnou k otázkám.'
                    : prep.summary,
              ),
              const AiDisclaimer(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: FilledButton(
            onPressed: () => setState(() => _stage = _Stage.quiz),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              'Spustit kvíz (${czechCount(prep.questions.length, 'otázka', 'otázky', 'otázek')})',
            ),
          ),
        ),
      ],
    );
  }

  Widget _quiz(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = _current;
    final answered = q.kind == ExamQuestionKind.choice
        ? _picked != null
        : _revealed;
    final pickedRight = _picked != null && _picked == q.correct;

    Widget option(int i) {
      final isRight = i == q.correct;
      final isPicked = i == _picked;
      final Color? tint = _picked != null && isRight
          ? Colors.green.withValues(alpha: .18)
          : isPicked && !isRight
          ? scheme.errorContainer
          : null;
      return Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Material(
          color: tint ?? scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _picked != null ? null : () => setState(() => _picked = i),
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(q.options[i], style: theme.textTheme.bodyLarge),
                  ),
                  if (_picked != null && isRight)
                    const Icon(Icons.check_circle, color: Colors.green),
                  if (isPicked && !isRight)
                    Icon(Icons.cancel, color: scheme.error),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Gap.lg),
            children: [
              Text(
                'OTÁZKA ${_answers.length + 1} / ${_prep!.questions.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                q.question,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: Gap.xl),
              if (q.kind == ExamQuestionKind.choice)
                for (var i = 0; i < q.options.length; i++) option(i)
              else if (_revealed)
                Text(
                  q.answer,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
                ),
              if (answered && q.explanation.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                Text(
                  q.explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: switch ((q.kind, answered)) {
            (ExamQuestionKind.choice, false) => const SizedBox(
              height: 52,
              child: Center(child: Text('Vyber odpověď')),
            ),
            (ExamQuestionKind.choice, true) => FilledButton(
              onPressed: () => _answer(pickedRight, given: q.options[_picked!]),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Další'),
            ),
            (ExamQuestionKind.open, false) => FilledButton(
              onPressed: () => setState(() => _revealed = true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Ukázat odpověď'),
            ),
            (ExamQuestionKind.open, true) => Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    style: tonalButtonStyle(context).copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(52),
                      ),
                    ),
                    onPressed: () => _answer(false),
                    child: const Text('Nevěděl/a jsem'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => _answer(true),
                    child: const Text('Věděl/a jsem'),
                  ),
                ),
              ],
            ),
          },
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final right = _answers.where((a) => a.correct).length;
    final wrong = _answers.length - right;
    final noteId = _noteId;
    return EmptyState(
      icon: Icons.emoji_events_outlined,
      title: '$right z ${_answers.length} správně',
      message: [
        if (wrong == 0) 'Všechno správně.',
        if (noteId != null) 'Shrnutí i otázky jsou uložené v poznámkách.',
        if (_added != null)
          _added == 0
              ? 'Tyhle otázky už v opakování jsou.'
              : 'Přidáno do opakování: '
                    '${czechCount(_added!, 'kartička', 'kartičky', 'kartiček')}.',
      ].join('\n'),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wrong > 0 && _added == null)
            FilledButton.icon(
              onPressed: _addMistakes,
              icon: const Icon(Icons.style_outlined),
              label: Text(
                'Přidat ${czechCount(wrong, 'chybu', 'chyby', 'chyb')} '
                'do opakování',
              ),
            ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            alignment: WrapAlignment.center,
            children: [
              if (noteId != null)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .pushReplacement(SavedNoteScreen.route(noteId)),
                  child: const Text('Otevřít poznámku'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Hotovo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
