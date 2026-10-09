import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/motion.dart';
import '../../core/spacing.dart';
import '../../core/widgets/count_chip.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/result_transition.dart';
import '../../core/widgets/inset_group.dart';
import '../../core/widgets/menu_row.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/saved_notes_dao.dart';
import '../settings/settings_screen.dart';
import '../subjects/subject_actions.dart';
import '../subjects/subjects_providers.dart';
import 'notes_library_providers.dart';
import 'saved_note_screen.dart';
import 'widgets/folder_sheets.dart';
import '../../core/pending_deletions.dart';

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
    final hidden = ref.watch(pendingIdsProvider(DeletionKind.note));
    final notes = ref
        .watch(savedNotesProvider)
        .whenData(
          (all) => hidden.isEmpty
              ? all
              : [
                  for (final n in all)
                    if (!hidden.contains(n.id)) n,
                ],
        );
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];

    // A folder deleted — here or from a note's sheet — takes its filter with it.
    FolderSummary? selected;
    for (final summary in folders) {
      if (_filter.folderId == summary.folder.id) selected = summary;
    }
    final filter = _filter.kind == FolderFilterKind.folder && selected == null
        ? FolderFilter.all
        : _filter;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Knihovna'),
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
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.xs,
                Gap.lg,
                Gap.sm,
              ),
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
          ),
          SliverToBoxAdapter(
            child: _FolderBar(
              filter: filter,
              folders: folders,
              notes: notes.valueOrNull ?? const [],
              onSelected: (value) => setState(() => _filter = value),
              onLongPress: (summary) => _showFolderMenu(summary),
              onCreate: _newFolder,
            ),
          ),
          AsyncSliver(
            value: notes,
            message: 'Poznámky se nepodařilo načíst.',
            onRetry: () => ref.invalidate(savedNotesProvider),
            builder: (all) => _buildList(all, filter, folders),
          ),
          SliverPadding(padding: EdgeInsets.only(bottom: Gap.xl + bottomInset)),
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
    Widget empty(Widget state) =>
        SliverFillRemaining(hasScrollBody: false, child: state);

    if (all.isEmpty) {
      return empty(
        const EmptyState(
          icon: Icons.bookmarks_outlined,
          title: 'Knihovna je zatím prázdná',
          message:
              'Otevři schůzku, v záložce Poznámky je vytvoř a klepni na '
              'Uložit. Tady je pak najdeš roztříděné podle předmětů.',
        ),
      );
    }

    final visible = filterSavedNotes(all, filter: filter, query: _search.text);
    if (visible.isEmpty) {
      return empty(
        _search.text.trim().isNotEmpty
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'Nic nenalezeno',
                message: 'Zkus jiné slovo nebo jiný předmět.',
              )
            : const EmptyState(
                icon: Icons.folder_open_outlined,
                title: 'Tady zatím nic není',
                message:
                    'Poznámku sem přesuneš v jejím detailu přes '
                    'Přesunout do předmětu.',
              ),
      );
    }

    final byId = {for (final f in folders) f.folder.id: f.folder};

    final firstPaint = _seen.isEmpty;
    final entering = <int, int>{};
    for (final note in visible) {
      if (_seen.add(note.id)) entering[note.id] = entering.length;
    }

    final label = switch (filter.kind) {
      FolderFilterKind.all => 'Všechny poznámky',
      FolderFilterKind.unfiled => 'Bez předmětu',
      FolderFilterKind.folder => byId[filter.folderId]?.name ?? 'Poznámky',
    };

    // One inset group: the notes share a surface, and a folder's colour shows
    // as the gradient on the row's tile rather than as another box.
    return SliverList(
      delegate: SliverChildListDelegate([
        ResultTransition(
          revision: (_search.text, filter),
          child: InsetGroup(
            label: label,
            trailingLabel: czechCount(
              visible.length,
              'poznámka',
              'poznámky',
              'poznámek',
            ),
            dividerIndent: Gap.lg + _NoteRow.slot,
            children: [
              for (final note in visible)
                Entrance(
                  key: ValueKey(note.id),
                  enabled: entering[note.id] != null,
                  delay: firstPaint && entering[note.id] != null
                      ? AppMotion.staggerDelay(entering[note.id]!)
                      : Duration.zero,
                  child: _NoteRow(
                    note: note,
                    subject: byId[note.folderId],
                    // In a folder's own view its name on every row is noise.
                    showSubject: filter.kind != FolderFilterKind.folder,
                  ),
                ),
            ],
          ),
        ),
      ]),
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
      CountChip(
        label: 'Vše',
        count: notes.length,
        selected: filter == FolderFilter.all,
        onSelected: () => onSelected(FolderFilter.all),
      ),
      for (final summary in folders)
        Semantics(
          hint: 'Dlouhým stiskem lze předmět přejmenovat nebo smazat.',
          onLongPress: () => onLongPress(summary),
          child: GestureDetector(
            onLongPress: () => onLongPress(summary),
            child: CountChip(
              avatar: SubjectDot(
                color: subjectColor(context, summary.folder.colorIndex),
              ),
              label: summary.folder.name,
              count: summary.noteCount,
              selected: filter.folderId == summary.folder.id,
              onSelected: () =>
                  onSelected(FolderFilter.folder(summary.folder.id)),
            ),
          ),
        ),
      // Only once there are subjects: before that every note is unfiled and the
      // chip would be a second „Vše".
      if (folders.isNotEmpty)
        CountChip(
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

    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return SizedBox(
      height: 48 * scale,
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

/// A saved note as a row: a gradient tile in its subject's colour (the
/// accent when it has none), title, when, and a two-line prose excerpt.
class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, this.subject, this.showSubject = true});

  final SavedNote note;
  final Subject? subject;
  final bool showSubject;

  static const slot = 52.0;

  @override
  Widget build(BuildContext context) {
    final subject = this.subject;
    final when = formatMeetingDate(note.updatedAt);
    return ListRow(
      leadingSlot: slot,
      leading: GradientIconTile(
        icon: Icons.sticky_note_2_rounded,
        color: subject == null
            ? null
            : subjectColor(context, subject.colorIndex),
      ),
      title: note.title,
      subtitle: showSubject && subject != null
          ? '${subject.name} · $when'
          : when,
      excerpt: notePreview(note.content),
      onTap: () => Navigator.of(context).push(SavedNoteScreen.route(note.id)),
    );
  }
}
