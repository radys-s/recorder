import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/spacing.dart';
import '../../subjects/subject_actions.dart';
import '../../subjects/subjects_providers.dart';
import '../../subjects/widgets/subject_badge.dart';
import '../notes_library_providers.dart';

/// Asks for a subject name and creates it. Folders became subjects in schema
/// v10; the library keeps its own name for the flow.
Future<int?> createFolderFlow(BuildContext context, WidgetRef ref) =>
    createSubjectFlow(context, ref);

/// Where to move a note. Resolves to a record so that "no subject" (`folderId`
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
      required Widget leading,
      required String label,
      required int? folderId,
    }) {
      final selected = folderId == currentFolderId;
      return ListTile(
        leading: leading,
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
              child: Text('Přesunout do předmětu',
                  style: theme.textTheme.titleMedium),
            ),
            tile(
              leading: const Icon(Icons.inbox_outlined),
              label: 'Bez předmětu',
              folderId: null,
            ),
            for (final summary in folders)
              tile(
                leading: SizedBox(
                  width: 24,
                  child: Center(
                    child: SubjectDot(
                      color: subjectColor(context, summary.folder.colorIndex),
                      size: 12,
                    ),
                  ),
                ),
                label: summary.folder.name,
                folderId: summary.folder.id,
              ),
            const Divider(indent: Gap.lg, endIndent: Gap.lg),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Nový předmět…'),
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

/// A row of subject chips to pick one from, with „Bez předmětu" first and a
/// chip that creates a new subject last.
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
          label: const Text('Bez předmětu'),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final summary in folders)
          ChoiceChip(
            avatar: SubjectDot(
              color: subjectColor(context, summary.folder.colorIndex),
            ),
            label: Text(summary.folder.name),
            selected: selected == summary.folder.id,
            onSelected: (_) => onChanged(summary.folder.id),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Nový předmět'),
          onPressed: () async {
            final id = await createFolderFlow(context, ref);
            if (id != null) onChanged(id);
          },
        ),
      ],
    );
  }
}
