import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/saved_notes_dao.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late SavedNotesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.savedNotesDao;
  });
  tearDown(() => db.close());

  Future<SavedNote> note(int id) =>
      (db.select(db.savedNotes)..where((t) => t.id.equals(id))).getSingle();

  group('saveNote', () {
    test('trims title and content and keeps the source', () async {
      final id = await dao.saveNote(
        title: '  Porada  ',
        content: '\n- Jan pošle nabídku\n\n',
        meetingId: 7,
        depth: NotesDepth.brief,
      );
      final saved = await note(id);
      expect(saved.title, 'Porada');
      expect(saved.content, '- Jan pošle nabídku');
      expect(saved.meetingId, 7);
      expect(saved.depth, NotesDepth.brief);
      expect(saved.folderId, isNull);
      expect(saved.updatedAt, saved.createdAt);
    });

    test('a blank title is a bug, not an empty row', () async {
      expect(
        () => dao.saveNote(title: '   ', content: 'x'),
        throwsArgumentError,
      );
      expect(await db.select(db.savedNotes).get(), isEmpty);
    });

    test('an over-long title is cut without splitting an emoji', () async {
      final title = '${'a' * (SavedNotesDao.maxTitleLength - 1)}😀';
      final id = await dao.saveNote(title: title, content: 'x');
      final saved = await note(id);
      expect(saved.title, 'a' * (SavedNotesDao.maxTitleLength - 1));
    });
  });

  group('updateNote', () {
    test('keeps the depth label while the text is unchanged', () async {
      final id = await dao.saveNote(
        title: 'A',
        content: '- bod',
        depth: NotesDepth.full,
      );
      await dao.updateNote(id, title: 'Nový název', content: '- bod  ');
      final saved = await note(id);
      expect(saved.title, 'Nový název');
      expect(saved.depth, NotesDepth.full);
    });

    test('drops the depth label once the text is edited', () async {
      final id = await dao.saveNote(
        title: 'A',
        content: '- bod',
        depth: NotesDepth.full,
      );
      await dao.updateNote(id, title: 'A', content: '- jiný bod');
      final saved = await note(id);
      expect(saved.content, '- jiný bod');
      expect(saved.depth, isNull);
    });

    test('a missing note is a no-op', () async {
      await dao.updateNote(404, title: 'A', content: 'b');
      expect(await db.select(db.savedNotes).get(), isEmpty);
    });
  });

  test('moving files a note without touching updatedAt', () async {
    final folder = await dao.createFolder('Čeština');
    final id = await dao.saveNote(title: 'A', content: 'b');
    final before = await note(id);

    await dao.moveNote(id, folder);
    final after = await note(id);
    expect(after.folderId, folder);
    expect(after.updatedAt, before.updatedAt);

    await dao.moveNote(id, null);
    expect((await note(id)).folderId, isNull);
  });

  test('watchNotes lists the most recently edited first', () async {
    final older = await dao.saveNote(title: 'Starší', content: 'a');
    final newer = await dao.saveNote(title: 'Novější', content: 'b');
    final notes = await dao.watchNotes().first;
    expect(notes.map((n) => n.id), [newer, older]);
  });

  test('watchForMeeting returns only that meeting\'s notes', () async {
    final a = await dao.saveNote(title: 'A', content: 'a', meetingId: 1);
    await dao.saveNote(title: 'B', content: 'b', meetingId: 2);
    await dao.saveNote(title: 'C', content: 'c');
    final notes = await dao.watchForMeeting(1).first;
    expect(notes.map((n) => n.id), [a]);
  });

  group('folders', () {
    test('a duplicate name returns the existing folder, Czech case too',
        () async {
      final first = await dao.createFolder('Čeština');
      expect(await dao.createFolder('  čeština '), first);
      expect(await dao.createFolder('ČEŠTINA'), first);
      expect(await dao.folders(), hasLength(1));
    });

    test('are listed in creation order with their note counts', () async {
      final cz = await dao.createFolder('Čeština');
      final en = await dao.createFolder('Angličtina');
      await dao.saveNote(title: 'A', content: 'a', folderId: cz);
      await dao.saveNote(title: 'B', content: 'b', folderId: cz);
      await dao.saveNote(title: 'C', content: 'c');

      final folders = await dao.watchFolders().first;
      expect(folders.map((f) => f.folder.id), [cz, en]);
      expect(folders.map((f) => f.noteCount), [2, 0]);
    });

    test('rename trims and rejects blank', () async {
      final id = await dao.createFolder('Cestina');
      await dao.renameFolder(id, ' Čeština ');
      expect((await dao.folders()).single.name, 'Čeština');
      expect(() => dao.renameFolder(id, '  '), throwsArgumentError);
    });

    test('deleting a folder keeps its notes, now unfiled', () async {
      final cz = await dao.createFolder('Čeština');
      final other = await dao.createFolder('Jiné');
      final inCz = await dao.saveNote(title: 'A', content: 'a', folderId: cz);
      final inOther =
          await dao.saveNote(title: 'B', content: 'b', folderId: other);

      await dao.deleteFolder(cz);

      expect((await dao.folders()).map((f) => f.id), [other]);
      expect((await note(inCz)).folderId, isNull);
      expect((await note(inOther)).folderId, other);
    });
  });

  test('deleteNote removes only that note', () async {
    final a = await dao.saveNote(title: 'A', content: 'a');
    final b = await dao.saveNote(title: 'B', content: 'b');
    await dao.deleteNote(a);
    final left = await db.select(db.savedNotes).get();
    expect(left.map((n) => n.id), [b]);
  });
}
