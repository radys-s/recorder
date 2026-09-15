import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notes_text.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/tables/meeting_notes_table.dart';
import '../../../data/db/tables/preferences_table.dart';
import '../../notes_library/notes_library_providers.dart';
import '../../notes_library/saved_note_screen.dart';
import '../../notes_library/widgets/save_note_sheet.dart';
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

  /// Keeps a copy of the notes in the library, under a title and folder the
  /// user picks.
  Future<void> _save(MeetingNote note) async {
    final dao = ref.read(savedNotesDaoProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final meeting = ref.read(meetingProvider(widget.meetingId)).valueOrNull;

    final picked = await showSaveNoteSheet(
      context,
      initialTitle: meeting?.title ?? 'Poznámky ze schůzky',
      initialFolderId: meeting?.subjectId,
    );
    if (picked == null) return;

    final id = await dao.saveNote(
      title: picked.title,
      content: note.content!,
      folderId: picked.folderId,
      meetingId: widget.meetingId,
      depth: note.depth,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Uloženo do knihovny.'),
          action: SnackBarAction(
            label: 'Otevřít',
            onPressed: () => navigator.push(SavedNoteScreen.route(id)),
          ),
        ),
      );
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

    // Matched on content rather than remembered from a tap: regenerating
    // produces different text, and the button must then offer to save again.
    int? savedId;
    final content = note?.content?.trim();
    for (final saved in ref
            .watch(savedNotesForMeetingProvider(widget.meetingId))
            .valueOrNull ??
        const <SavedNote>[]) {
      if (saved.content == content) savedId = saved.id;
    }

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
            saved: savedId != null,
            onCopy: () => _copy(note.content!),
            onSave: () => savedId != null
                ? Navigator.of(context).push(SavedNoteScreen.route(savedId))
                : _save(note),
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
    required this.saved,
    required this.onCopy,
    required this.onSave,
  });

  final MeetingNote note;

  /// True while a regenerate is running, when what is on screen is the previous
  /// version rather than the one being made.
  final bool stale;

  /// Whether exactly this text is already in the library. Tapping the button
  /// then opens that note instead of saving a second copy.
  final bool saved;

  final VoidCallback onCopy;
  final VoidCallback onSave;

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
              const SizedBox(width: Gap.xs),
              FilledButton.tonalIcon(
                onPressed: stale ? null : onSave,
                icon: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                  size: 18,
                ),
                label: Text(saved ? 'Uloženo' : 'Uložit'),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          NotesText(content: note.content!),
        ],
      ),
    );
  }
}
