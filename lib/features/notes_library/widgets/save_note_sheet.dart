import 'package:flutter/material.dart';

import '../../../core/spacing.dart';
import '../../../data/db/daos/saved_notes_dao.dart';
import 'folder_sheets.dart';

/// Title and subject for a note about to be saved, or null when cancelled.
/// [initialFolderId] preselects the lesson's own subject.
Future<({String title, int? folderId})?> showSaveNoteSheet(
  BuildContext context, {
  required String initialTitle,
  int? initialFolderId,
}) {
  return showModalBottomSheet<({String title, int? folderId})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SaveNoteSheet(
      initialTitle: initialTitle,
      initialFolderId: initialFolderId,
    ),
  );
}

class _SaveNoteSheet extends StatefulWidget {
  const _SaveNoteSheet({required this.initialTitle, this.initialFolderId});

  final String initialTitle;
  final int? initialFolderId;

  @override
  State<_SaveNoteSheet> createState() => _SaveNoteSheetState();
}

class _SaveNoteSheetState extends State<_SaveNoteSheet> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late int? _folderId = widget.initialFolderId;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop((title: title, folderId: _folderId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _title.text.trim().isNotEmpty;

    return Padding(
      // Rides up with the keyboard, so the save button is never under it.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Uložit poznámky', style: theme.textTheme.titleLarge),
              const SizedBox(height: Gap.xs),
              Text(
                'Uloží se kopie. Když poznámky u schůzky vytvoříš znovu nebo '
                'schůzku smažeš, tahle verze zůstane.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.xl),
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
              Text('Předmět', style: theme.textTheme.titleSmall),
              const SizedBox(height: Gap.sm),
              FolderChipPicker(
                selected: _folderId,
                onChanged: (id) => setState(() => _folderId = id),
              ),
              const SizedBox(height: Gap.xl),
              FilledButton.icon(
                onPressed: canSave ? _save : null,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Uložit do knihovny'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
