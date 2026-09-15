import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/subjects_dao.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late SubjectsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.subjectsDao;
  });
  tearDown(() => db.close());

  Future<int> meeting({int? subjectId, DateTime? at}) =>
      db.meetingsDao.insertMeeting(MeetingsCompanion.insert(
        title: 'Hodina',
        createdAt: at ?? DateTime(2026, 9, 15, 8),
        subjectId: Value(subjectId),
      ));

  test('watchSubjects counts cards, notes and lessons per subject', () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final ma = await db.savedNotesDao.createFolder('Matematika');
    await dao.createCard(subjectId: cz, title: 'Máj');
    await dao.createCard(subjectId: cz, title: 'Babička');
    await db.savedNotesDao.saveNote(title: 'a', content: 'b', folderId: cz);
    await meeting(subjectId: cz);
    await meeting(subjectId: cz);
    await meeting(subjectId: ma);

    final list = await dao.watchSubjects().first;
    expect(list.map((s) => s.subject.name), ['Čeština', 'Matematika']);
    expect(
      [list[0].cardCount, list[0].noteCount, list[0].lessonCount],
      [2, 1, 2],
    );
    expect(
      [list[1].cardCount, list[1].noteCount, list[1].lessonCount],
      [0, 0, 1],
    );
    // Colours are spread instead of every subject starting on the same one.
    expect(list[0].subject.colorIndex, isNot(list[1].subject.colorIndex));
  });

  test('deleteSubject removes cards and pins, keeps notes and lessons',
      () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final other = await db.savedNotesDao.createFolder('Dějepis');
    final card = await dao.createCard(subjectId: cz, title: 'Máj');
    final kept = await dao.createCard(subjectId: other, title: 'Husité');
    final lesson = await meeting(subjectId: cz);
    await dao.pinCards(lesson, [card, kept]);
    final noteId =
        await db.savedNotesDao.saveNote(title: 'a', content: 'b', folderId: cz);

    await dao.deleteSubject(cz);

    expect(await dao.subject(cz), isNull);
    expect(await dao.cards(cz), isEmpty);
    expect(await dao.cards(other), hasLength(1));
    expect(await dao.pinnedCardIds(lesson), [kept]);
    final note = await (db.select(db.savedNotes)
          ..where((t) => t.id.equals(noteId)))
        .getSingle();
    expect(note.folderId, isNull);
    final m = await db.meetingsDao.watchMeetingByIdOnce(lesson);
    expect(m!.subjectId, isNull);
  });

  test('pinCards replaces the set and ignores duplicates', () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final a = await dao.createCard(subjectId: cz, title: 'A');
    final b = await dao.createCard(subjectId: cz, title: 'B');
    final lesson = await meeting(subjectId: cz);

    await dao.pinCards(lesson, [a, a, b]);
    expect((await dao.pinnedCardIds(lesson))..sort(), [a, b]..sort());

    await dao.pinCards(lesson, [b]);
    expect(await dao.pinnedCardIds(lesson), [b]);
    expect((await dao.watchPinnedCards(lesson).first).single.title, 'B');

    await dao.pinCards(lesson, const []);
    expect(await dao.pinnedCardIds(lesson), isEmpty);
  });

  test('lastPinnedCardIds proposes the latest lesson of that subject',
      () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final ma = await db.savedNotesDao.createFolder('Matematika');
    final a = await dao.createCard(subjectId: cz, title: 'A');
    final b = await dao.createCard(subjectId: cz, title: 'B');
    final old = await meeting(subjectId: cz, at: DateTime(2026, 9, 1));
    final recent = await meeting(subjectId: cz, at: DateTime(2026, 9, 8));
    await meeting(subjectId: ma, at: DateTime(2026, 9, 10));
    await dao.pinCards(old, [a]);
    await dao.pinCards(recent, [b]);

    expect(await dao.lastPinnedCardIds(cz), [b]);
    expect(await dao.lastPinnedCardIds(ma), isEmpty);
    expect(await dao.lastUsedSubjectId(), ma);
  });

  test('setMeetingSubject drops pins that belong to another subject',
      () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final ma = await db.savedNotesDao.createFolder('Matematika');
    final czCard = await dao.createCard(subjectId: cz, title: 'Máj');
    final maCard = await dao.createCard(subjectId: ma, title: 'Zlomky');
    final lesson = await meeting(subjectId: cz);
    await dao.pinCards(lesson, [czCard, maCard]);

    await dao.setMeetingSubject(lesson, cz);
    expect(await dao.pinnedCardIds(lesson), [czCard]);

    await dao.setMeetingSubject(lesson, null);
    expect(await dao.pinnedCardIds(lesson), isEmpty);
    expect((await db.meetingsDao.watchMeetingByIdOnce(lesson))!.subjectId,
        isNull);
  });

  test('updateCard clears the digest only when the content changed', () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final id = await dao.createCard(subjectId: cz, title: 'Máj', content: 'x');
    await (db.update(db.contextCards)..where((t) => t.id.equals(id))).write(
      const ContextCardsCompanion(
        summary: Value('shrnutí'),
        keywords: Value('Mácha'),
      ),
    );

    await dao.updateCard(id, title: 'Máj (K. H. Mácha)', content: 'x');
    var card = (await dao.watchCard(id).first)!;
    expect(card.title, 'Máj (K. H. Mácha)');
    expect(card.summary, 'shrnutí');

    await dao.updateCard(id, title: card.title, content: 'y');
    card = (await dao.watchCard(id).first)!;
    expect(card.content, 'y');
    expect(card.summary, isNull);
    expect(card.keywords, isNull);
  });

  test('rules are trimmed and blank clears them', () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    await dao.setSubjectRules(cz, '  Odpovídej krátce  ');
    expect((await dao.subject(cz))!.rules, 'Odpovídej krátce');
    await dao.setSubjectRules(cz, '   ');
    expect((await dao.subject(cz))!.rules, isNull);
  });

  test('deleting a meeting removes its pins and chat', () async {
    final cz = await db.savedNotesDao.createFolder('Čeština');
    final card = await dao.createCard(subjectId: cz, title: 'Máj');
    final lesson = await meeting(subjectId: cz);
    await dao.pinCards(lesson, [card]);
    await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
          meetingId: lesson,
          role: ChatRole.user,
          intent: ChatIntent.context,
          atMs: 0,
          status: ChatStatus.ready,
          createdAt: DateTime.now(),
        ));

    await db.meetingsDao.deleteMeeting(lesson);

    expect(await dao.pinnedCardIds(lesson), isEmpty);
    expect(await db.select(db.chatMessages).get(), isEmpty);
    expect(await dao.cards(cz), hasLength(1));
  });

  test('requiredText cuts without splitting a surrogate pair', () {
    expect(requiredText('ab😀', 3, 'x'), 'ab');
    expect(() => requiredText('  ', 3, 'x'), throwsArgumentError);
  });
}
