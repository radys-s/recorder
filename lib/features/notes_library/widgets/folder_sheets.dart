import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../data/db/daos/saved_notes_dao.dart';
import '../notes_library_providers.dart';

/// Asks for a folder name and creates the folder. Resolves to its id — the
/// existing one when a folder of that name is already there — or null when
/// cancelled.
Future<int?> createFolderFlow(BuildContext context, WidgetRef ref) async {
  final dao = ref.read(savedNotesDaoProvider);
  final name = await showTextInputDialog(
    context,
    title: 'Nová složka',
    label: 'Název, třeba Čeština',
    confirmLabel: 'Vytvořit',
    maxLength: SavedNotesDao.maxFolderNameLength,
  );
  if (name == null) return null;
  return dao.createFolder(name);
}

/// Where to move a note. Resolves to a record so that "no folder" (`folderId`
/// null) and "cancelled" (the whole result null) cannot be confused.
Future<({int? folderId})?> showMoveToFolderSheet(
  BuildContext context, {
  required int? currentFolderId,
}) {
  return showModalBottomSheet<({int? folderId})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MoveToFolderSheet(currentFolderId: currentFolderId),
  );
}

class _MoveToFolderSheet extends ConsumerWidget {
  const _MoveToFolderSheet({required this.currentFolderId});

  final int? currentFolderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];

    Widget tile({
      required IconData icon,
      required String label,
      required int? folderId,
    }) {
      final selected = folderId == currentFolderId;
      return ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: selected
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null,
        selected: selected,
        onTap: () => Navigator.of(context).pop((folderId: folderId)),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Gap.sm),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
              child: Text('Přesunout do složky',
                  style: theme.textTheme.titleMedium),
            ),
            tile(
              icon: Icons.inbox_outlined,
              label: 'Bez složky',
              folderId: null,
            ),
            for (final summary in folders)
              tile(
                icon: Icons.folder_outlined,
                label: summary.folder.name,
                folderId: summary.folder.id,
              ),
            const Divider(indent: Gap.lg, endIndent: Gap.lg),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Nová složka…'),
              onTap: () async {
                final id = await createFolderFlow(context, ref);
                if (id != null && context.mounted) {
                  Navigator.of(context).pop((folderId: id));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of folder chips to pick one from, with „Bez složky" first and a chip
/// that creates a new folder last.
class FolderChipPicker extends ConsumerWidget {
  const FolderChipPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];

    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        ChoiceChip(
          avatar: const Icon(Icons.inbox_outlined, size: 18),
          label: const Text('Bez složky'),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final summary in folders)
          ChoiceChip(
            avatar: const Icon(Icons.folder_outlined, size: 18),
            label: Text(summary.folder.name),
            selected: selected == summary.folder.id,
            onSelected: (_) => onChanged(summary.folder.id),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Nová složka'),
          onPressed: () async {
            final id = await createFolderFlow(context, ref);
            if (id != null) onChanged(id);
          },
        ),
      ],
    );
  }
}
