import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/meetings_list/meeting_actions.dart';
import 'package:recorder/features/notes_library/notes_library_providers.dart';

void main() {
  final at = DateTime(2026, 9, 14);

  SavedNote note(int id, String title, String content, {int? folderId}) =>
      SavedNote(
        id: id,
        title: title,
        content: content,
        folderId: folderId,
        createdAt: at,
        updatedAt: at,
      );

  final notes = [
    note(1, 'Slovní druhy', '- podstatná jména\n- přídavná jména', folderId: 5),
    note(2, 'Rozpočet Q3', '- zbývá 1,2 milionu', folderId: 6),
    note(3, 'Nápady', '- přeložit web do češtiny'),
  ];

  List<int> ids(List<SavedNote> list) => [for (final n in list) n.id];

  group('filterSavedNotes', () {
    test('no filter and no query keeps everything in order', () {
      expect(ids(filterSavedNotes(notes)), [1, 2, 3]);
    });

    test('folder filters', () {
      expect(
        ids(filterSavedNotes(notes, filter: const FolderFilter.folder(5))),
        [1],
      );
      expect(ids(filterSavedNotes(notes, filter: FolderFilter.unfiled)), [3]);
      expect(
        ids(filterSavedNotes(notes, filter: const FolderFilter.folder(99))),
        isEmpty,
      );
    });

    test('search ignores diacritics and case', () {
      expect(ids(filterSavedNotes(notes, query: 'ROZPOCET')), [2]);
      expect(ids(filterSavedNotes(notes, query: 'cestiny')), [3]);
    });

    test('every word must match, in any order, title or text', () {
      expect(ids(filterSavedNotes(notes, query: 'jmena slovni')), [1]);
      expect(ids(filterSavedNotes(notes, query: 'jmena rozpocet')), isEmpty);
    });

    test('a blank or punctuation-only query does not filter', () {
      expect(ids(filterSavedNotes(notes, query: '   ')), [1, 2, 3]);
      expect(ids(filterSavedNotes(notes, query: '?!')), [1, 2, 3]);
    });

    test('query and folder combine', () {
      expect(
        ids(filterSavedNotes(
          notes,
          filter: FolderFilter.unfiled,
          query: 'jmena',
        )),
        isEmpty,
      );
    });
  });

  test('FolderFilter equality', () {
    expect(const FolderFilter.folder(3), const FolderFilter.folder(3));
    expect(const FolderFilter.folder(3) == const FolderFilter.folder(4), isFalse);
    expect(FolderFilter.all == FolderFilter.unfiled, isFalse);
  });

  group('notePreview', () {
    test('drops bullet marks and blank lines', () {
      expect(
        notePreview('Rozhodnutí:\n- Jan pošle nabídku\n\n• Eva zavolá\n* hotovo'),
        'Rozhodnutí: · Jan pošle nabídku · Eva zavolá · hotovo',
      );
    });

    test('keeps a hyphen that is not a bullet', () {
      expect(notePreview('Česko-slovenský tým'), 'Česko-slovenský tým');
    });
  });

  group('isDefaultMeetingTitle', () {
    test('matches the generated title', () {
      expect(isDefaultMeetingTitle('Schůzka 08.09. 09:50'), isTrue);
    });

    test('anything the user wrote is a custom title', () {
      expect(isDefaultMeetingTitle('Porada s Janem'), isFalse);
      expect(isDefaultMeetingTitle('Schůzka 08.09. 09:50 – klient'), isFalse);
      expect(isDefaultMeetingTitle('Schůzka'), isFalse);
    });
  });
}
