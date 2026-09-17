import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/pending_deletions.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/subject_terms_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/stt/term_corrections.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('applyTermCorrections', () {
    test('replaces whole words without case or diacritics', () {
      final r = applyTermCorrections(
        'Prosko přišel. A pak prosko, a pak Prosko!',
        [(heard: 'prosko', term: 'Proško')],
      );
      expect(r.text, 'Proško přišel. A pak Proško, a pak Proško!');
      expect(r.applied, {0});
    });

    test('never rewrites inside a longer word', () {
      final r = applyTermCorrections('Proskoviny nejsou prosko.', [
        (heard: 'prosko', term: 'Proško'),
      ]);
      expect(r.text, 'Proskoviny nejsou Proško.');
    });

    test('keeps a sentence-initial capital for a lowercase term', () {
      final r = applyTermCorrections('Realizmus je směr. O realizmu víme.', [
        (heard: 'realizmus', term: 'realismus'),
      ]);
      expect(r.text, 'Realismus je směr. O realizmu víme.');
    });

    test('matches multi-word heard forms across a gap, not a sentence end', () {
      const pairs = [(heard: 'bože na němcová', term: 'Božena Němcová')];
      expect(
        applyTermCorrections('Psala to bože  na-němcová.', pairs).text,
        'Psala to Božena Němcová.',
      );
      final split = applyTermCorrections('Ó bože. Na němcová.', pairs);
      expect(split.text, 'Ó bože. Na němcová.');
      expect(split.applied, isEmpty);
    });

    test('prefers the longest heard form and never corrects twice', () {
      final r = applyTermCorrections('viktor ka zpívala', [
        (heard: 'viktor', term: 'Viktorka'),
        (heard: 'viktor ka', term: 'Viktorka'),
      ]);
      expect(r.text, 'Viktorka zpívala');
      expect(r.applied, {1});
    });

    test('a replacement equal to the original is not counted', () {
      final r = applyTermCorrections('Proško', [
        (heard: 'prosko', term: 'Proško'),
      ]);
      expect(r.text, 'Proško');
      expect(r.applied, isEmpty);
    });
  });

  group('subject terms', () {
    late AppDatabase db;
    late int subject;
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      subject = await db.savedNotesDao.createFolder('Čeština');
    });
    tearDown(() => db.close());

    test('dedupes on folded term and heard form', () async {
      final a = await db.subjectsDao.addTerm(subject, 'Proško');
      final b = await db.subjectsDao.addTerm(subject, 'prosko');
      expect(b, a);
      final c = await db.subjectsDao.addTerm(
        subject,
        'Proško',
        heard: 'prosko',
      );
      expect(c, isNot(a));
      expect(await db.subjectsDao.terms(subject), hasLength(2));
    });

    test('a user-made term upgrades an automatic one', () async {
      await db.subjectsDao.addTerms(subject, [
        'viktorka',
        ' ',
        'x' * 81,
      ], TermSource.card);
      final rows = await db.subjectsDao.terms(subject);
      expect(rows.single.source, TermSource.card);
      await db.subjectsDao.addTerm(subject, 'Viktorka');
      final upgraded = (await db.subjectsDao.terms(subject)).single;
      expect(upgraded.term, 'Viktorka');
      expect(upgraded.source, TermSource.manual);
    });

    test('rejects a correction whose heard form is the term itself', () {
      expect(
        db.subjectsDao.addTerm(subject, 'Máj', heard: ' Máj '),
        throwsArgumentError,
      );
    });

    test(
      'uses are bumped and deleting the subject removes its terms',
      () async {
        final id = await db.subjectsDao.addTerm(subject, 'Máj');
        await db.subjectsDao.bumpTermUses([id, id]);
        expect((await db.subjectsDao.terms(subject)).single.uses, 1);
        await db.subjectsDao.deleteSubject(subject);
        expect(await db.subjectsDao.terms(subject), isEmpty);
      },
    );
  });

  group('segment corrections', () {
    late AppDatabase db;
    late int segment;
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final meeting = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(title: 'Hodina', createdAt: DateTime(2026)),
      );
      segment = await db.transcriptSegmentsDao.insertSegment(
        TranscriptSegmentsCompanion.insert(
          meetingId: meeting,
          sequence: 0,
          startMs: 0,
          endMs: 8000,
          content: const Value('Prosko přišel.'),
          status: SegmentStatus.transcribed,
          localAudioPath: 'a.wav',
          createdAt: DateTime(2026),
        ),
      );
    });
    tearDown(() => db.close());

    test(
      'keeps the first original across corrections and restores it',
      () async {
        final dao = db.transcriptSegmentsDao;
        await dao.correctSegment(segment, 'Proško přišel.');
        await dao.correctSegment(segment, 'Proško odešel.');
        var row = (await dao.segmentById(segment))!;
        expect(row.content, 'Proško odešel.');
        expect(row.rawContent, 'Prosko přišel.');

        await dao.restoreSegment(segment);
        row = (await dao.segmentById(segment))!;
        expect(row.content, 'Prosko přišel.');
        expect(row.rawContent, isNull);
      },
    );

    test('an unchanged text stores no original', () async {
      await db.transcriptSegmentsDao.correctSegment(segment, 'Prosko přišel.');
      expect(
        (await db.transcriptSegmentsDao.segmentById(segment))!.rawContent,
        isNull,
      );
    });
  });

  group('PendingDeletions', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          deletionUndoWindowProvider.overrideWithValue(
            const Duration(seconds: 5),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('undo keeps the item and never commits', () {
      fakeAsync((async) {
        final c = container();
        var committed = 0;
        final n = c.read(pendingDeletionsProvider.notifier);
        n.schedule(DeletionKind.note, 7, () async => committed++);
        expect(c.read(pendingIdsProvider(DeletionKind.note)), {7});
        expect(c.read(pendingIdsProvider(DeletionKind.card)), isEmpty);

        expect(n.undo(DeletionKind.note, 7), isTrue);
        async.elapse(const Duration(seconds: 10));
        expect(committed, 0);
        expect(c.read(pendingDeletionsProvider), isEmpty);
        expect(n.undo(DeletionKind.note, 7), isFalse);
      });
    });

    test('the window running out commits once', () {
      fakeAsync((async) {
        final c = container();
        var committed = 0;
        final n = c.read(pendingDeletionsProvider.notifier);
        n.schedule(DeletionKind.meeting, 3, () async => committed++);
        n.schedule(DeletionKind.meeting, 3, () async => committed++);
        async.elapse(const Duration(seconds: 4));
        expect(committed, 0);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(committed, 1);
        expect(c.read(pendingDeletionsProvider), isEmpty);
        expect(n.undo(DeletionKind.meeting, 3), isFalse);
      });
    });

    test('commitAll runs everything pending at once', () {
      fakeAsync((async) {
        final c = container();
        final done = <int>[];
        final n = c.read(pendingDeletionsProvider.notifier);
        n.schedule(DeletionKind.card, 1, () async => done.add(1));
        n.schedule(DeletionKind.note, 2, () async => done.add(2));
        n.commitAll();
        async.flushMicrotasks();
        expect(done, [1, 2]);
        expect(c.read(pendingDeletionsProvider), isEmpty);
        async.elapse(const Duration(seconds: 10));
        expect(done, [1, 2]);
      });
    });

    test('a failing delete still leaves the pending set', () {
      fakeAsync((async) {
        final c = container();
        final n = c.read(pendingDeletionsProvider.notifier);
        n.schedule(DeletionKind.card, 1, () async => throw StateError('x'));
        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();
        expect(c.read(pendingDeletionsProvider), isEmpty);
      });
    });
  });
}
