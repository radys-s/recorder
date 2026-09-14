import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/menu_row.dart';
import '../../core/widgets/notes_text.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/saved_notes_dao.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import 'notes_library_providers.dart';
import 'widgets/folder_sheets.dart';

enum _NoteAction { move, openMeeting, delete }

/// One saved note, read in full.
class SavedNoteScreen extends ConsumerWidget {
  const SavedNoteScreen({super.key, required this.noteId});

  final int noteId;

  static Route<void> route(int noteId) => MaterialPageRoute<void>(
        builder: (_) => SavedNoteScreen(noteId: noteId),
      );

  Future<void> _copy(BuildContext context, SavedNote note) async {
    await Clipboard.setData(ClipboardData(text: note.content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Zkopírováno.')));
  }

  Future<void> _move(BuildContext context, WidgetRef ref, SavedNote note) async {
    final dao = ref.read(savedNotesDaoProvider);
    final picked = await showMoveToFolderSheet(
      context,
      currentFolderId: note.folderId,
    );
    if (picked == null || picked.folderId == note.folderId) return;
    await dao.moveNote(note.id, picked.folderId);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedNote note) async {
    final dao = ref.read(savedNotesDaoProvider);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.delete_outline,
      title: 'Smazat poznámku?',
      message: 'Zmizí z knihovny. Schůzka a její poznámky zůstanou, jak jsou.',
      confirmLabel: 'Smazat',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    // Closed first, so the screen never flashes „Poznámka už neexistuje".
    Navigator.of(context).pop();
    await dao.deleteNote(note.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Poznámka je smazaná.')));
  }

  void _onAction(
    BuildContext context,
    WidgetRef ref,
    SavedNote note,
    _NoteAction action,
  ) {
    switch (action) {
      case _NoteAction.move:
        _move(context, ref, note);
      case _NoteAction.openMeeting:
        Navigator.of(context).push(MeetingDetailScreen.route(note.meetingId!));
      case _NoteAction.delete:
        _delete(context, ref, note);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(savedNoteProvider(noteId));
    final note = value.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        actions: note == null
            ? const []
            : [
                IconButton(
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip: 'Kopírovat',
                  onPressed: () => _copy(context, note),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Upravit',
                  onPressed: () => Navigator.of(context)
                      .push(SavedNoteEditorScreen.route(note)),
                ),
                PopupMenuButton<_NoteAction>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Další akce',
                  onSelected: (action) =>
                      _onAction(context, ref, note, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _NoteAction.move,
                      child: MenuRow(
                        icon: Icons.drive_file_move_outline,
                        label: 'Přesunout do složky',
                      ),
                    ),
                    if (note.meetingId != null)
                      const PopupMenuItem(
                        value: _NoteAction.openMeeting,
                        child: MenuRow(
                          icon: Icons.open_in_new,
                          label: 'Otevřít schůzku',
                        ),
                      ),
                    const PopupMenuItem(
                      value: _NoteAction.delete,
                      child: MenuRow(
                        icon: Icons.delete_outline,
                        label: 'Smazat',
                        destructive: true,
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: AsyncView(
        value: value,
        message: 'Poznámku se nepodařilo načíst.',
        onRetry: () => ref.invalidate(savedNoteProvider(noteId)),
        builder: (note) => note == null
            ? const EmptyState(
                icon: Icons.bookmark_remove_outlined,
                title: 'Poznámka už neexistuje',
              )
            : _SavedNoteBody(
                note: note,
                onMove: () => _move(context, ref, note),
              ),
      ),
    );
  }
}

class _SavedNoteBody extends ConsumerWidget {
  const _SavedNoteBody({required this.note, required this.onMove});

  final SavedNote note;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];
    String? folderName;
    for (final summary in folders) {
      if (summary.folder.id == note.folderId) folderName = summary.folder.name;
    }
    final edited = note.updatedAt.difference(note.createdAt).inSeconds > 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.xxl),
      children: [
        Text(note.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            // The folder chip is also the quickest way to refile the note.
            InkWell(
              onTap: onMove,
              borderRadius: BorderRadius.circular(Gap.sm),
              child: StatusChip(
                icon: folderName == null
                    ? Icons.inbox_outlined
                    : Icons.folder_outlined,
                label: folderName ?? 'Bez složky',
                tone: folderName == null ? ChipTone.neutral : ChipTone.progress,
              ),
            ),
            StatusChip(
              icon: edited ? Icons.edit_outlined : Icons.bookmark_outline,
              label: edited
                  ? 'Upraveno ${formatMeetingDate(note.updatedAt)}'
                  : 'Uloženo ${formatMeetingDate(note.createdAt)}',
            ),
            if (note.depth != null)
              StatusChip(
                icon: Icons.tune,
                label: note.depth!.label,
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: Gap.lg),
          child: Divider(),
        ),
        NotesText(content: note.content),
      ],
    );
  }
}

/// Rewriting a saved note by hand.
class SavedNoteEditorScreen extends ConsumerStatefulWidget {
  const SavedNoteEditorScreen({super.key, required this.note});

  final SavedNote note;

  static Route<void> route(SavedNote note) => MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SavedNoteEditorScreen(note: note),
      );

  @override
  ConsumerState<SavedNoteEditorScreen> createState() =>
      _SavedNoteEditorScreenState();
}

class _SavedNoteEditorScreenState extends ConsumerState<SavedNoteEditorScreen> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _content = TextEditingController(text: widget.note.content);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _title.text != widget.note.title || _content.text != widget.note.content;

  bool get _canSave =>
      !_saving &&
      _title.text.trim().isNotEmpty &&
      _content.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    await ref.read(savedNotesDaoProvider).updateNote(
          widget.note.id,
          title: _title.text,
          content: _content.text,
        );
    navigator.pop();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Zahodit změny?',
      message: 'Úpravy se neuloží.',
      confirmLabel: 'Zahodit',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // A back swipe over unsaved text asks first; Navigator.pop from the
      // buttons below is not affected by this.
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upravit poznámku'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: TextButton(
                onPressed: _canSave ? _save : null,
                child: const Text('Uložit'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
          children: [
            TextField(
              controller: _title,
              maxLength: SavedNotesDao.maxTitleLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Název'),
              buildCounter: (_, {required currentLength, required isFocused,
                      maxLength}) =>
                  null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _content,
              minLines: 12,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Text',
                alignLabelWithHint: true,
                helperText: 'Řádek začínající „- " je odrážka, krátký řádek '
                    'končící dvojtečkou je nadpis.',
                helperMaxLines: 2,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
