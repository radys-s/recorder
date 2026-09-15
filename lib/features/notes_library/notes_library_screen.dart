import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/motion.dart';
import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/menu_row.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/saved_notes_dao.dart';
import '../settings/settings_screen.dart';
import '../subjects/subject_actions.dart';
import '../subjects/subjects_providers.dart';
import '../subjects/widgets/subject_badge.dart';
import 'notes_library_providers.dart';
import 'saved_note_screen.dart';
import 'widgets/folder_sheets.dart';

/// The notes the user kept: searchable, sorted into folders.
class NotesLibraryScreen extends ConsumerStatefulWidget {
  const NotesLibraryScreen({super.key});

  @override
  ConsumerState<NotesLibraryScreen> createState() => _NotesLibraryScreenState();
}

enum _FolderAction { rename, delete }

class _NotesLibraryScreenState extends ConsumerState<NotesLibraryScreen> {
  final _search = TextEditingController();
  FolderFilter _filter = FolderFilter.all;

  /// Note ids whose entrance has played; see `MeetingsListScreen._seen`.
  final _seen = <int>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newFolder() async {
    final id = await createFolderFlow(context, ref);
    if (id != null && mounted) {
      setState(() => _filter = FolderFilter.folder(id));
    }
  }

  Future<void> _renameFolder(Subject folder) =>
      renameSubjectFlow(context, ref, folder);

  Future<void> _deleteFolder(FolderSummary summary) async {
    final deleted = await confirmAndDeleteSubject(context, ref, summary.folder);
    if (deleted && mounted) setState(() => _filter = FolderFilter.all);
  }

  void _folderAction(_FolderAction action, FolderSummary summary) {
    switch (action) {
      case _FolderAction.rename:
        _renameFolder(summary.folder);
      case _FolderAction.delete:
        _deleteFolder(summary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(savedNotesProvider);
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];

    // A folder deleted — here or from a note's sheet — takes its filter with it.
    FolderSummary? selected;
    for (final summary in folders) {
      if (_filter.folderId == summary.folder.id) selected = summary;
    }
    final filter = _filter.kind == FolderFilterKind.folder && selected == null
        ? FolderFilter.all
        : _filter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poznámky'),
        actions: [
          if (selected != null)
            PopupMenuButton<_FolderAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Předmět',
              onSelected: (action) => _folderAction(action, selected!),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _FolderAction.rename,
                  child: MenuRow(
                    icon: Icons.drive_file_rename_outline,
                    label: 'Přejmenovat předmět',
                  ),
                ),
                PopupMenuItem(
                  value: _FolderAction.delete,
                  child: MenuRow(
                    icon: Icons.delete_outline,
                    label: 'Smazat předmět',
                    destructive: true,
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.sm),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Hledat v poznámkách',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Vymazat hledání',
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          _FolderBar(
            filter: filter,
            folders: folders,
            notes: notes.valueOrNull ?? const [],
            onSelected: (value) => setState(() => _filter = value),
            onLongPress: (summary) => _showFolderMenu(summary),
            onCreate: _newFolder,
          ),
          Expanded(
            child: AsyncView(
              value: notes,
              message: 'Poznámky se nepodařilo načíst.',
              onRetry: () => ref.invalidate(savedNotesProvider),
              builder: (all) => _buildList(all, filter, folders),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFolderMenu(FolderSummary summary) async {
    final action = await showModalBottomSheet<_FolderAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
              child: Text(
                summary.folder.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Přejmenovat'),
              onTap: () => Navigator.of(context).pop(_FolderAction.rename),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Smazat předmět',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(_FolderAction.delete),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
    if (action != null && mounted) _folderAction(action, summary);
  }

  Widget _buildList(
    List<SavedNote> all,
    FolderFilter filter,
    List<FolderSummary> folders,
  ) {
    if (all.isEmpty) {
      return const EmptyState(
        icon: Icons.bookmarks_outlined,
        title: 'Knihovna je zatím prázdná',
        message: 'Otevři schůzku, v záložce Poznámky je vytvoř a klepni na '
            'Uložit. Tady je pak najdeš roztříděné podle předmětů.',
      );
    }

    final visible = filterSavedNotes(all, filter: filter, query: _search.text);
    if (visible.isEmpty) {
      return _search.text.trim().isNotEmpty
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'Nic nenalezeno',
              message: 'Zkus jiné slovo nebo jiný předmět.',
            )
          : const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Tady zatím nic není',
              message: 'Poznámku sem přesuneš v jejím detailu přes '
                  'Přesunout do předmětu.',
            );
    }

    final names = {for (final f in folders) f.folder.id: f.folder.name};

    final firstPaint = _seen.isEmpty;
    final entering = <int, int>{};
    for (final note in visible) {
      if (_seen.add(note.id)) entering[note.id] = entering.length;
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xl),
      itemCount: visible.length,
      itemBuilder: (_, i) {
        final note = visible[i];
        final order = entering[note.id];
        return Entrance(
          enabled: order != null,
          delay: firstPaint && order != null
              ? AppMotion.staggerDelay(order)
              : Duration.zero,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: _SavedNoteCard(
              note: note,
              // In a folder's own view its name on every card is noise.
              folderName: filter.kind == FolderFilterKind.folder
                  ? null
                  : names[note.folderId],
            ),
          ),
        );
      },
    );
  }
}

class _FolderBar extends StatelessWidget {
  const _FolderBar({
    required this.filter,
    required this.folders,
    required this.notes,
    required this.onSelected,
    required this.onLongPress,
    required this.onCreate,
  });

  final FolderFilter filter;
  final List<FolderSummary> folders;
  final List<SavedNote> notes;
  final ValueChanged<FolderFilter> onSelected;
  final ValueChanged<FolderSummary> onLongPress;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final unfiled = notes.where((n) => n.folderId == null).length;

    final chips = <Widget>[
      _FilterChip(
        label: 'Vše',
        count: notes.length,
        selected: filter == FolderFilter.all,
        onSelected: () => onSelected(FolderFilter.all),
      ),
      for (final summary in folders)
        GestureDetector(
          onLongPress: () => onLongPress(summary),
          child: _FilterChip(
            avatar: SubjectDot(
              color: subjectColor(context, summary.folder.colorIndex),
            ),
            label: summary.folder.name,
            count: summary.noteCount,
            selected: filter.folderId == summary.folder.id,
            onSelected: () => onSelected(FolderFilter.folder(summary.folder.id)),
          ),
        ),
      // Only once there are subjects: before that every note is unfiled and the
      // chip would be a second „Vše".
      if (folders.isNotEmpty)
        _FilterChip(
          avatar: const Icon(Icons.inbox_outlined, size: 18),
          label: 'Bez předmětu',
          count: unfiled,
          selected: filter == FolderFilter.unfiled,
          onSelected: () => onSelected(FolderFilter.unfiled),
        ),
      ActionChip(
        avatar: const Icon(Icons.add, size: 18),
        label: const Text('Nový předmět'),
        onPressed: onCreate,
      ),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    this.avatar,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ChoiceChip(
      avatar: avatar,
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: Gap.sm - 2),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedNoteCard extends StatelessWidget {
  const _SavedNoteCard({required this.note, this.folderName});

  final SavedNote note;
  final String? folderName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(SavedNoteScreen.route(note.id)),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(Gap.md),
                ),
                child: Icon(
                  Icons.sticky_note_2_outlined,
                  size: 19,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      notePreview(note.content),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        if (folderName != null) ...[
                          Icon(Icons.folder_outlined,
                              size: 14, color: scheme.primary),
                          const SizedBox(width: Gap.xs),
                          Flexible(
                            child: Text(
                              folderName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: Gap.md),
                        ],
                        Text(
                          formatMeetingDate(note.updatedAt),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
