import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/dialogs.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/saved_notes_dao.dart';
import 'subjects_providers.dart';

/// Asks for a subject name and creates it. Resolves to its id — the existing
/// one when a subject of that name is already there — or null when cancelled.
Future<int?> createSubjectFlow(BuildContext context, WidgetRef ref) async {
  final dao = ref.read(appDatabaseProvider).savedNotesDao;
  final name = await showTextInputDialog(
    context,
    title: 'Nový předmět',
    label: 'Název, třeba Čeština',
    confirmLabel: 'Vytvořit',
    maxLength: SavedNotesDao.maxFolderNameLength,
  );
  if (name == null) return null;
  return dao.createFolder(name);
}

Future<void> renameSubjectFlow(
  BuildContext context,
  WidgetRef ref,
  Subject subject,
) async {
  final dao = ref.read(appDatabaseProvider).savedNotesDao;
  final name = await showTextInputDialog(
    context,
    title: 'Přejmenovat předmět',
    label: 'Název',
    initialValue: subject.name,
    maxLength: SavedNotesDao.maxFolderNameLength,
  );
  if (name == null || name == subject.name) return;
  await dao.renameFolder(subject.id, name);
}

/// Asks, then deletes the subject with its cards. Says what goes and what
/// stays, because the cards are the part the user typed by hand. Resolves to
/// whether it was deleted.
Future<bool> confirmAndDeleteSubject(
  BuildContext context,
  WidgetRef ref,
  Subject subject,
) async {
  final dao = ref.read(subjectsDaoProvider);
  final cards = (await dao.cards(subject.id)).length;
  if (!context.mounted) return false;

  final confirmed = await showConfirmDialog(
    context,
    icon: Icons.delete_outline,
    title: 'Smazat předmět „${subject.name}"?',
    message: cards == 0
        ? 'Poznámky a nahrané hodiny zůstanou, jen bez předmětu.'
        : 'Smaže se i ${czechCount(cards, 'karta', 'karty', 'karet')}. '
            'Poznámky a nahrané hodiny zůstanou, jen bez předmětu.',
    confirmLabel: 'Smazat',
    destructive: true,
  );
  if (!confirmed) return false;
  await dao.deleteSubject(subject.id);
  return true;
}
