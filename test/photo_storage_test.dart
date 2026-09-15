import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recorder/ai/answer_source.dart';
import 'package:recorder/ai/lesson_context_source.dart';
import 'package:recorder/core/photo_files.dart';
import 'package:recorder/data/card_deleter.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/data/db/tables/context_cards_table.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late Directory docs;
  late AppDatabase db;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('recorder_photos_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  final bytes = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);
  final at = DateTime(2026, 9, 15, 9);

  File resolved(String stored) =>
      File(p.join(docs.path, p.joinAll(p.split(stored))));

  group('photo files', () {
    test('savePhoto writes under the dir and returns a relative path',
        () async {
      final stored = await savePhoto(
        docsPath: docs.path,
        dir: meetingPhotosDir(docs.path, 3),
        bytes: bytes,
        now: at,
      );
      expect(p.isAbsolute(stored), isFalse);
      expect(p.split(stored).take(2), ['photos', 'meeting_3']);
      expect(await resolved(stored).readAsBytes(), bytes);
    });

    test('two photos in the same instant get different names', () async {
      final dir = cardPhotosDir(docs.path, 1);
      final a = await savePhoto(docsPath: docs.path, dir: dir, bytes: bytes, now: at);
      final b = await savePhoto(docsPath: docs.path, dir: dir, bytes: bytes, now: at);
      expect(a, isNot(b));
      expect(await Directory(dir).list().length, 2);
    });

    test('copyPhotos copies into the card and skips missing files', () async {
      final source = await savePhoto(
        docsPath: docs.path,
        dir: meetingPhotosDir(docs.path, 7),
        bytes: bytes,
      );
      final copies = await copyPhotos(
        docsPath: docs.path,
        dir: cardPhotosDir(docs.path, 2),
        storedPaths: [source, 'photos/meeting_7/gone.jpg'],
      );
      expect(copies, hasLength(1));
      expect(p.split(copies.single).take(2), ['cards', 'card_2']);
      // A copy, so deleting the meeting's photos leaves the card's intact.
      await removeDirectory(meetingPhotosDir(docs.path, 7));
      expect(await resolved(copies.single).readAsBytes(), bytes);
    });

    test('removeDirectory ignores a directory that is not there', () async {
      await removeDirectory(p.join(docs.path, 'nope'));
    });

    test('photoMimeType', () {
      expect(photoMimeType('a/photo.JPG'), 'image/jpeg');
      expect(photoMimeType('a/photo.png'), 'image/png');
      expect(photoMimeType('a/photo.heic'), 'image/heic');
      expect(photoMimeType('a/photo'), 'image/jpeg');
    });
  });

  group('card photos and sources in SubjectsDao', () {
    test('images append in order after the existing ones', () async {
      final subject = await db.savedNotesDao.createFolder('Čeština');
      final card = await db.subjectsDao.createCard(subjectId: subject, title: 'Máj');
      await db.subjectsDao.addCardImages(card, ['a.jpg', 'b.jpg']);
      await db.subjectsDao.addCardImages(card, ['c.jpg']);
      await db.subjectsDao.addCardImages(card, []);
      expect(await db.subjectsDao.cardImagePaths(card), ['a.jpg', 'b.jpg', 'c.jpg']);
    });

    test('sources are stored on create and replaced later', () async {
      final subject = await db.savedNotesDao.createFolder('Čeština');
      final encoded = encodeAnswerSources([
        AnswerSource(title: 'Wiki', url: Uri.parse('https://cs.wikipedia.org/a')),
      ]);
      final card = await db.subjectsDao.createCard(
        subjectId: subject,
        title: 'Babička',
        kind: CardKind.lookup,
        sources: encoded,
      );
      var row = (await db.subjectsDao.cards(subject)).single;
      expect(row.sources, encoded);
      expect(row.kind, CardKind.lookup);

      await db.subjectsDao.setCardSources(card, null);
      row = (await db.subjectsDao.cards(subject)).single;
      expect(row.sources, isNull);
    });
  });

  group('CardDeleter', () {
    Future<(int, int, int)> seed() async {
      final subject = await db.savedNotesDao.createFolder('Čeština');
      final a = await db.subjectsDao.createCard(subjectId: subject, title: 'A');
      final b = await db.subjectsDao.createCard(subjectId: subject, title: 'B');
      for (final id in [a, b]) {
        final stored = await savePhoto(
          docsPath: docs.path,
          dir: cardPhotosDir(docs.path, id),
          bytes: bytes,
        );
        await db.subjectsDao.addCardImages(id, [stored]);
      }
      return (subject, a, b);
    }

    CardDeleter deleter() =>
        CardDeleter(db.subjectsDao, documentsPath: () async => docs.path);

    test('deleteCard removes the row, its images and only its photos',
        () async {
      final (_, a, b) = await seed();
      await deleter().deleteCard(a);

      expect(await db.subjectsDao.cardImagePaths(a), isEmpty);
      expect(await Directory(cardPhotosDir(docs.path, a)).exists(), isFalse);
      expect(await Directory(cardPhotosDir(docs.path, b)).exists(), isTrue);
    });

    test('deleteSubject removes every card\'s photos', () async {
      final (subject, a, b) = await seed();
      await deleter().deleteSubject(subject);

      expect(await db.subjectsDao.cards(subject), isEmpty);
      expect(await Directory(cardPhotosDir(docs.path, a)).exists(), isFalse);
      expect(await Directory(cardPhotosDir(docs.path, b)).exists(), isFalse);
    });

    test('unreachable storage is logged, the rows still go', () async {
      final (subject, _, _) = await seed();
      await CardDeleter(
        db.subjectsDao,
        documentsPath: () async => throw const FileSystemException('nope'),
      ).deleteSubject(subject);
      expect(await db.subjectsDao.cards(subject), isEmpty);
    });
  });

  group('board photo messages', () {
    Future<int> meeting() => db.meetingsDao.insertMeeting(
          MeetingsCompanion.insert(title: 'Hodina', createdAt: at),
        );

    test('pending → ready keeps text in body and description in short',
        () async {
      final m = await meeting();
      final id = await db.chatMessagesDao
          .addPhotoMessage(meetingId: m, imagePath: 'photos/x.jpg', atMs: 5000);
      var row = (await db.chatMessagesDao.message(id))!;
      expect(row.intent, ChatIntent.photo);
      expect(row.role, ChatRole.user);
      expect(row.status, ChatStatus.pending);

      await db.chatMessagesDao
          .completePhoto(id, text: 'E = mc²', description: 'Vzorec.');
      row = (await db.chatMessagesDao.message(id))!;
      expect(row.status, ChatStatus.ready);
      expect(row.body, 'E = mc²');
      expect(row.short, 'Vzorec.');
    });

    test('a failure keeps its reason out of the body', () async {
      final m = await meeting();
      final id = await db.chatMessagesDao
          .addPhotoMessage(meetingId: m, imagePath: 'photos/x.jpg', atMs: 0);
      await db.chatMessagesDao.failPhoto(id, 'Gemini teď neodpovídá.');
      final row = (await db.chatMessagesDao.message(id))!;
      expect(row.status, ChatStatus.failed);
      expect(row.body, isEmpty);
      expect(row.detail, 'Gemini teď neodpovídá.');
    });

    test('a photo still pending at startup becomes a visible failure',
        () async {
      final m = await meeting();
      final id = await db.chatMessagesDao
          .addPhotoMessage(meetingId: m, imagePath: 'photos/x.jpg', atMs: 0);
      expect(await db.chatMessagesDao.failInterruptedReplies(), 1);
      final row = (await db.chatMessagesDao.message(id))!;
      expect(row.status, ChatStatus.failed);
      expect(row.body, isEmpty);
      expect(row.detail, contains('fotka'));
    });

    test('lesson context carries read photos only', () async {
      final m = await meeting();
      final ready = await db.chatMessagesDao
          .addPhotoMessage(meetingId: m, imagePath: 'photos/a.jpg', atMs: 0);
      await db.chatMessagesDao.completePhoto(ready,
          text: 'Mitochondrie', description: 'Nákres buňky');
      await db.chatMessagesDao
          .addPhotoMessage(meetingId: m, imagePath: 'photos/b.jpg', atMs: 1);
      final failed = await db.chatMessagesDao
          .addPhotoMessage(meetingId: m, imagePath: 'photos/c.jpg', atMs: 2);
      await db.chatMessagesDao.failPhoto(failed, 'Chyba');

      final material = await LessonContextSource(db).load(m);
      expect(material.chatContext,
          ['Photo of the board (Nákres buňky):\nMitochondrie']);
    });
  });
}
