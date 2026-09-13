import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/tables/meeting_notes_table.dart';
import '../../../data/db/tables/preferences_table.dart';
import '../meeting_detail_providers.dart';

/// The "Poznámky" tab: pick a depth, press the button, read the result.
///
/// Nothing here is generated automatically — an unopened meeting costs no Groq
/// calls, and re-generating at another depth is one tap away.
class MeetingNotesTab extends ConsumerStatefulWidget {
  const MeetingNotesTab({super.key, required this.meetingId});

  final int meetingId;

  @override
  ConsumerState<MeetingNotesTab> createState() => _MeetingNotesTabState();
}

class _MeetingNotesTabState extends ConsumerState<MeetingNotesTab> {
  /// Null until the user picks one or a stored row tells us what was used last;
  /// see [_effectiveDepth].
  NotesDepth? _picked;

  Future<void> _generate(NotesDepth depth) async {
    // The generator writes its own progress and failure to the row, so this
    // deliberately does not await anything the UI depends on.
    unawaited(
      ref.read(notesGeneratorProvider).generate(
            meetingId: widget.meetingId,
            depth: depth,
          ),
    );
  }

  Future<void> _copy(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Zkopírováno.')));
  }

  /// What the depth selector shows: the user's choice this session, else the
  /// depth the stored notes were made at, else the saved default from Settings.
  NotesDepth _effectiveDepth(MeetingNote? note) {
    return _picked ??
        note?.depth ??
        ref.watch(preferencesProvider).valueOrNull?.notesDepth ??
        NotesDepth.standard;
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(meetingNotesProvider(widget.meetingId));
    final note = notes.valueOrNull;
    final depth = _effectiveDepth(note);
    final generating = note?.status == NotesStatus.generating;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.lg, Gap.lg, Gap.fabClearance),
      children: [
        Text('Hloubka poznámek',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Gap.sm),
        SegmentedButton<NotesDepth>(
          segments: [
            for (final value in NotesDepth.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {depth},
          onSelectionChanged:
              generating ? null : (set) => setState(() => _picked = set.first),
        ),
        const SizedBox(height: Gap.md),
        FilledButton.icon(
          onPressed: generating ? null : () => _generate(depth),
          icon: const Icon(Icons.auto_awesome),
          label: Text(note == null ? 'Vytvořit poznámky' : 'Vytvořit znovu'),
        ),
        const SizedBox(height: Gap.xl),
        if (generating) const _GeneratingIndicator(),
        if (note?.status == NotesStatus.failed && note?.error != null)
          _NotesError(message: note!.error!),
        if (note?.content != null && note!.content!.trim().isNotEmpty)
          _NotesBody(
            note: note,
            stale: generating,
            onCopy: () => _copy(note.content!),
          )
        else if (note == null)
          const EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: 'Zatím žádné poznámky',
            message: 'Vyber hloubku a nech je vytvořit. Kdykoliv je '
                'můžeš přegenerovat jinak.',
          ),
      ],
    );
  }
}

class _GeneratingIndicator extends StatelessWidget {
  const _GeneratingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: Gap.sm),
          Text(
            'Generuji poznámky…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NotesError extends StatelessWidget {
  const _NotesError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: Gap.xl),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Poznámky se nepodařilo vytvořit',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesBody extends StatelessWidget {
  const _NotesBody({
    required this.note,
    required this.stale,
    required this.onCopy,
  });

  final MeetingNote note;

  /// True while a regenerate is running, when what is on screen is the previous
  /// version rather than the one being made.
  final bool stale;

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dimmed while a regenerate runs. Faded rather than switched, so the
    // moment the new version lands reads as the text coming back rather than
    // as the screen blinking.
    return AnimatedOpacity(
      opacity: stale ? 0.5 : 1,
      duration:
          reducedMotion(context) ? Duration.zero : AppDuration.quick,
      curve: AppCurve.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stale
                      ? 'Předchozí verze (${note.depth.label})'
                      : note.depth.label,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_outlined),
                tooltip: 'Kopírovat',
                onPressed: onCopy,
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          _NotesText(content: note.content!),
        ],
      ),
    );
  }
}

/// The generated notes, laid out.
///
/// The prompts produce plain text — `- ` bullets, short heading lines ending in
/// a colon, blank lines between blocks — and it stays plain text on purpose, so
/// the copy button hands over something that pastes cleanly anywhere. Rendering
/// it verbatim in a single `Text` is what made it read badly: a wrapped bullet
/// came back to the left margin and the list stopped looking like a list.
///
/// Flutter cannot hang-indent inside one text run, so each block is its own
/// widget. The cost is that a drag-selection stops at a block boundary; the
/// copy button above covers "give me all of it", which is what people actually
/// want from notes.
class _NotesText extends StatelessWidget {
  const _NotesText({required this.content});

  final String content;

  /// The bullet's own text, or null if the line is not a bullet. Models are
  /// inconsistent about which mark they use even when the prompt says `- `.
  static final _bullet = RegExp(r'^\s*[-•*–]\s+(.*)$');

  /// A short line ending in a colon is one of the prompts' section headings
  /// (`Rozhodnutí:`, `Úkoly:`). The length cap keeps an ordinary sentence that
  /// happens to end in a colon from being promoted to a heading.
  static bool _isHeading(String line) =>
      line.endsWith(':') && line.length <= 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.45);

    final blocks = <Widget>[];
    var gap = false;

    void add(Widget block) {
      if (gap && blocks.isNotEmpty) {
        blocks.add(const SizedBox(height: Gap.md));
      }
      gap = false;
      blocks.add(block);
    }

    for (final raw in content.trim().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        gap = true;
        continue;
      }

      final bullet = _bullet.firstMatch(line)?.group(1)?.trim();
      if (bullet != null && bullet.isNotEmpty) {
        add(
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A real bullet glyph rather than the model's hyphen, in a
                // fixed-width box so every line of text starts on the same
                // column no matter how the marks differ.
                SizedBox(
                  width: Gap.lg,
                  child: Text(
                    '•',
                    style: body?.copyWith(color: scheme.outline),
                  ),
                ),
                Expanded(child: SelectableText(bullet, style: body)),
              ],
            ),
          ),
        );
        continue;
      }

      if (_isHeading(line)) {
        add(
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
            child: Text(
              line,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
        );
        continue;
      }

      add(
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.xs),
          child: SelectableText(line, style: body),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}
