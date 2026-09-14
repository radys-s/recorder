import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/daos/saved_notes_dao.dart';
import '../../stt/transcript_sanitizer.dart';

final savedNotesDaoProvider = Provider<SavedNotesDao>((ref) {
  return ref.watch(appDatabaseProvider).savedNotesDao;
});

/// Every saved note, most recently edited first.
final savedNotesProvider = StreamProvider<List<SavedNote>>((ref) {
  return ref.watch(savedNotesDaoProvider).watchNotes();
});

/// Folders in creation order, each with its note count.
final noteFoldersProvider = StreamProvider<List<FolderSummary>>((ref) {
  return ref.watch(savedNotesDaoProvider).watchFolders();
});

final savedNoteProvider = StreamProvider.family<SavedNote?, int>((ref, id) {
  return ref.watch(savedNotesDaoProvider).watchNote(id);
});

/// What one meeting has in the library — lets the notes tab show whether the
/// notes on screen are already saved.
final savedNotesForMeetingProvider =
    StreamProvider.family<List<SavedNote>, int>((ref, meetingId) {
  return ref.watch(savedNotesDaoProvider).watchForMeeting(meetingId);
});

enum FolderFilterKind { all, unfiled, folder }

/// Which part of the library is showing: everything, the notes in no folder,
/// or one folder.
@immutable
class FolderFilter {
  const FolderFilter._(this.kind, this.folderId);

  const FolderFilter.folder(int id) : this._(FolderFilterKind.folder, id);

  static const all = FolderFilter._(FolderFilterKind.all, null);
  static const unfiled = FolderFilter._(FolderFilterKind.unfiled, null);

  final FolderFilterKind kind;
  final int? folderId;

  bool matches(SavedNote note) => switch (kind) {
        FolderFilterKind.all => true,
        FolderFilterKind.unfiled => note.folderId == null,
        FolderFilterKind.folder => note.folderId == folderId,
      };

  @override
  bool operator ==(Object other) =>
      other is FolderFilter && other.kind == kind && other.folderId == folderId;

  @override
  int get hashCode => Object.hash(kind, folderId);
}

/// The notes a filter and a search query leave.
///
/// Every word of the query has to appear somewhere in the title or the text,
/// in any order, compared with diacritics folded — someone typing „cestina"
/// on a phone keyboard is looking for „Čeština".
List<SavedNote> filterSavedNotes(
  List<SavedNote> notes, {
  FolderFilter filter = FolderFilter.all,
  String query = '',
}) {
  final words = normalizeForArtifactMatch(query)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();

  return [
    for (final note in notes)
      if (filter.matches(note) && _containsAll(note, words)) note,
  ];
}

bool _containsAll(SavedNote note, List<String> words) {
  if (words.isEmpty) return true;
  final haystack = normalizeForArtifactMatch('${note.title}\n${note.content}');
  return words.every(haystack.contains);
}

/// A one-paragraph preview of a note for a list row: bullet marks dropped and
/// lines run together, so two preview lines carry two lines of content rather
/// than one bullet and a blank.
String notePreview(String content) {
  final bullet = RegExp(r'^\s*[-•*–]\s+');
  return content
      .split('\n')
      .map((line) => line.replaceFirst(bullet, '').trim())
      .where((line) => line.isNotEmpty)
      .join(' · ');
}
