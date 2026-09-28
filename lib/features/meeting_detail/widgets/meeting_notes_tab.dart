import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accent.dart';
import '../../../ai/card_suggestions.dart';
import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/share.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notes_text.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/tables/context_cards_table.dart';
import '../../../data/db/tables/meeting_notes_table.dart';
import '../../../data/db/tables/preferences_table.dart';
import '../../notes_library/notes_library_providers.dart';
import '../../notes_library/saved_note_screen.dart';
import '../../notes_library/widgets/save_note_sheet.dart';
import '../../subjects/subjects_providers.dart';
import '../meeting_detail_providers.dart';
import '../transcript_fix.dart';

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
      ref
          .read(notesGeneratorProvider)
          .generate(meetingId: widget.meetingId, depth: depth),
    );
  }

  /// Plain text out of the app: into a notebook app, a chat, or NotebookLM
  /// until the Docs sync exists.
  Future<void> _share(BuildContext context, String content) async {
    final meeting = ref.read(meetingProvider(widget.meetingId)).valueOrNull;
    await shareText(
      context,
      title: meeting?.title ?? 'Výpisky',
      content: content,
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

  /// Turns a suggestion into a card of the lesson's subject.
  Future<void> _addSuggestion(CardSuggestion suggestion, int subjectId) async {
    final messenger = ScaffoldMessenger.of(context);
    final digests = ref.read(cardDigestServiceProvider);
    final id = await ref
        .read(subjectsDaoProvider)
        .createCard(
          subjectId: subjectId,
          title: suggestion.title,
          content: suggestion.content,
          kind: CardKind.lesson,
        );
    unawaited(digests.digest(id));
    await _dropSuggestion(suggestion);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Karta „${suggestion.title}" přidána.')),
      );
  }

  /// Removes one suggestion, read fresh so two quick taps cannot resurrect
  /// the other.
  Future<void> _dropSuggestion(CardSuggestion suggestion) async {
    final dao = ref.read(appDatabaseProvider).meetingNotesDao;
    final row = await dao.forMeeting(widget.meetingId);
    if (row == null) return;
    final rest = [
      for (final s in decodeCardSuggestions(row.cardSuggestions))
        if (s != suggestion) s,
    ];
    await dao.setCardSuggestions(widget.meetingId, encodeCardSuggestions(rest));
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
    final subjectId = ref
        .watch(meetingProvider(widget.meetingId))
        .valueOrNull
        ?.subjectId;
    final lesson = subjectId != null;
    final editedAt = ref.watch(transcriptEditedAtProvider)[widget.meetingId];
    final outdated =
        !generating &&
        note?.content != null &&
        editedAt != null &&
        editedAt.isAfter(note!.createdAt);
    final suggestions = lesson && !generating
        ? decodeCardSuggestions(note?.cardSuggestions)
        : const <CardSuggestion>[];

    // Matched on content rather than remembered from a tap: regenerating
    // produces different text, and the button must then offer to save again.
    int? savedId;
    final content = note?.content?.trim();
    for (final saved
        in ref
                .watch(savedNotesForMeetingProvider(widget.meetingId))
                .valueOrNull ??
            const <SavedNote>[]) {
      if (saved.content == content) savedId = saved.id;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Gap.lg,
        Gap.lg,
        Gap.lg,
        Gap.fabClearance,
      ),
      children: [
        Text(
          lesson ? 'Hloubka výpisků' : 'Hloubka poznámek',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final value in NotesDepth.ordered)
              ChoiceChip(
                label: Text(value.label),
                selected: value == depth,
                onSelected: generating
                    ? null
                    : (_) => setState(() => _picked = value),
              ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        Text(
          lesson ? depth.lessonDescription : depth.description,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Gap.md),
        FilledButton.icon(
          onPressed: generating ? null : () => _generate(depth),
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            note == null
                ? (lesson ? 'Vytvořit výpisky' : 'Vytvořit poznámky')
                : 'Vytvořit znovu',
          ),
        ),
        const SizedBox(height: Gap.xl),
        if (outdated) ...[
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Přepis se změnil'),
              subtitle: Text(
                lesson
                    ? 'Výpisky jsou ze starší verze přepisu.'
                    : 'Poznámky jsou ze starší verze přepisu.',
              ),
              trailing: TextButton(
                onPressed: () => _generate(depth),
                child: const Text('Vytvořit znovu'),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
        ],
        if (generating) const _GeneratingIndicator(),
        if (note?.status == NotesStatus.failed && note?.error != null)
          _NotesError(message: note!.error!),
        if (note?.content != null && note!.content!.trim().isNotEmpty)
          _NotesBody(
            note: note,
            stale: generating,
            saved: savedId != null,
            onCopy: () => _copy(note.content!),
            onShare: (ctx) => _share(ctx, note.content!),
            onSave: () => savedId != null
                ? Navigator.of(context).push(SavedNoteScreen.route(savedId))
                : _save(note),
          )
        else if (note == null)
          EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: lesson ? 'Zatím žádné výpisky' : 'Zatím žádné poznámky',
            message: lesson
                ? 'Výpisky do sešitu z přepisu, fotek tabule, kontextu a '
                      'otázek z hodiny.'
                : 'Vyber hloubku a nech je vytvořit. Kdykoliv je '
                      'můžeš přegenerovat jinak.',
          ),
        if (suggestions.isNotEmpty && subjectId != null)
          _CardSuggestions(
            suggestions: suggestions,
            onAdd: (s) => _addSuggestion(s, subjectId),
            onDismiss: _dropSuggestion,
          ),
      ],
    );
  }
}

/// Topics from the výpisky that could become cards.
class _CardSuggestions extends StatelessWidget {
  const _CardSuggestions({
    required this.suggestions,
    required this.onAdd,
    required this.onDismiss,
  });

  final List<CardSuggestion> suggestions;
  final ValueChanged<CardSuggestion> onAdd;
  final ValueChanged<CardSuggestion> onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Uložit jako kartu', style: theme.textTheme.titleSmall),
          const SizedBox(height: Gap.sm),
          for (final s in suggestions)
            Card(
              key: ValueKey(s.title),
              margin: const EdgeInsets.only(bottom: Gap.sm),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.md,
                  Gap.sm,
                  Gap.xs,
                  Gap.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: theme.textTheme.titleSmall),
                          const SizedBox(height: Gap.xs),
                          Text(
                            s.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Nechci',
                      onPressed: () => onDismiss(s),
                    ),
                    FilledButton.tonal(
                      style: tonalButtonStyle(context),
                      onPressed: () => onAdd(s),
                      child: const Text('Přidat'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
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
    required this.onShare,
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

  /// Takes the context of the button, which is what an iPad anchors the share
  /// popover to.
  final void Function(BuildContext) onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dimmed while a regenerate runs. Faded rather than switched, so the
    // moment the new version lands reads as the text coming back rather than
    // as the screen blinking.
    return AnimatedOpacity(
      opacity: stale ? 0.5 : 1,
      duration: reducedMotion(context) ? Duration.zero : AppDuration.quick,
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
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_outlined),
                tooltip: 'Kopírovat',
                onPressed: onCopy,
              ),
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Sdílet',
                  onPressed: () => onShare(ctx),
                ),
              ),
              const SizedBox(width: Gap.xs),
              FilledButton.tonalIcon(
                style: tonalButtonStyle(context),
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
