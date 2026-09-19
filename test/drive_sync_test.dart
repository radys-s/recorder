import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/drive_docs_table.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/sync/drive_api.dart';
import 'package:recorder/sync/drive_sync_service.dart';

/// Drive in memory: folders and docs by id, plus queued failures.
class _Drive implements DriveApi {
  final folders = <String, bool>{}; // id -> binned
  final docs = <String, String>{}; // id -> html
  final names = <String, String>{};
  final calls = <String>[];
  final failures = <String, List<DriveException>>{};
  var _next = 0;

  void failNext(String call, DriveException e) =>
      (failures[call] ??= []).add(e);

  void _maybeFail(String call) {
    final queued = failures[call];
    if (queued != null && queued.isNotEmpty) throw queued.removeAt(0);
  }

  @override
  Future<String> createFolder(String name) async {
    calls.add('createFolder');
    _maybeFail('createFolder');
    final id = 'folder${_next++}';
    folders[id] = false;
    return id;
  }

  @override
  Future<bool> folderExists(String id) async {
    calls.add('folderExists');
    _maybeFail('folderExists');
    return folders[id] == false;
  }

  @override
  Future<String> createDoc({
    required String name,
    required String folderId,
    required String html,
  }) async {
    calls.add('createDoc');
    _maybeFail('createDoc');
    if (folders[folderId] != false) throw const DriveNotFoundException();
    final id = 'doc${_next++}';
    docs[id] = html;
    names[id] = name;
    return id;
  }

  @override
  Future<void> updateDoc(
    String id, {
    required String name,
    required String html,
  }) async {
    calls.add('updateDoc');
    _maybeFail('updateDoc');
    if (!docs.containsKey(id)) throw const DriveNotFoundException();
    docs[id] = html;
    names[id] = name;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late _Drive drive;
  late DriveSyncService sync;
  var invalidated = 0;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    drive = _Drive();
    invalidated = 0;
    sync = DriveSyncService(
      db,
      api: drive,
      invalidateAccessToken: () => invalidated++,
      now: () => DateTime(2026, 9, 19, 10),
      retryDelay: const Duration(days: 1),
    );
    await db.preferencesDao.setGoogleAccountEmail('s@example.com');
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  Future<int> lesson(int subjectId, String notes, {bool ended = true}) async {
    final id = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title: 'Hodina',
        createdAt: DateTime(2026, 9, 16, 8),
        endedAt: Value(ended ? DateTime(2026, 9, 16, 8, 45) : null),
        subjectId: Value(subjectId),
      ),
    );
    await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
    await db.meetingNotesDao.markReady(id, notes);
    await db.transcriptSegmentsDao.insertSegment(
      TranscriptSegmentsCompanion.insert(
        meetingId: id,
        sequence: 0,
        startMs: 0,
        endMs: 10000,
        content: const Value('Dnes probereme směrování.'),
        status: SegmentStatus.transcribed,
        localAudioPath: 'x.wav',
        createdAt: DateTime(2026, 9, 16),
      ),
    );
    return id;
  }

  test('nobody signed in: nothing is tried', () async {
    await db.preferencesDao.setGoogleAccountEmail(null);
    final report = await sync.syncAll();
    expect(report.outcome, DriveSyncOutcome.notSignedIn);
    expect(drive.calls, isEmpty);
  });

  test('a subject with nothing written yet produces no doc', () async {
    await db.savedNotesDao.createFolder('Sítě');
    final report = await sync.syncAll();
    expect(report.outcome, DriveSyncOutcome.synced);
    expect(report.uploaded + report.skipped, 0);
    expect(drive.calls, isEmpty);
  });

  test('first sync creates folder and doc, next one updates the same id',
      () async {
    final subject = await db.savedNotesDao.createFolder('Sítě');
    final meeting = await lesson(subject, '- VLAN');

    final first = await sync.syncAll();
    expect(first.outcome, DriveSyncOutcome.synced);
    expect(first.uploaded, 1);
    final row = await db.driveDocsDao.doc(subject, DriveDocKind.notes);
    final docId = row!.docId!;
    expect(drive.docs[docId], contains('VLAN'));
    expect(drive.names[docId], contains('Sítě'));
    expect(row.syncedAt, DateTime(2026, 9, 19, 10));
    expect((await db.preferencesDao.current()).driveFolderId, 'folder0');

    final unchanged = await sync.syncAll();
    expect(unchanged.uploaded, 0);
    expect(unchanged.skipped, 1);

    await db.meetingNotesDao.markReady(meeting, '- VLAN\n- OSPF');
    drive.calls.clear();
    final changed = await sync.syncAll();
    expect(changed.uploaded, 1);
    expect(drive.calls, ['updateDoc']);
    expect(drive.docs[docId], contains('OSPF'));
    expect(drive.docs, hasLength(1));
  });

  test('force uploads even when nothing changed', () async {
    final subject = await db.savedNotesDao.createFolder('Sítě');
    await lesson(subject, '- VLAN');
    await sync.syncAll();
    final forced = await sync.syncAll(force: true);
    expect(forced.uploaded, 1);
    expect(forced.skipped, 0);
  });

  test('a doc deleted in Drive is created again', () async {
    final subject = await db.savedNotesDao.createFolder('Sítě');
    await lesson(subject, '- VLAN');
    await sync.syncAll();
    final old = (await db.driveDocsDao.doc(subject, DriveDocKind.notes))!.docId!;
    drive.docs.remove(old);

    final report = await sync.syncAll(force: true);
    expect(report.outcome, DriveSyncOutcome.synced);
    final now = (await db.driveDocsDao.doc(subject, DriveDocKind.notes))!.docId!;
    expect(now, isNot(old));
    expect(drive.docs.keys, [now]);
  });

  test('a binned folder: new folder, docs forgotten and recreated', () async {
    final subject = await db.savedNotesDao.createFolder('Sítě');
    await lesson(subject, '- VLAN');
    await sync.syncAll();
    drive.folders['folder0'] = true;
    drive.docs.clear();

    final report = await sync.syncAll(force: true);
    expect(report.outcome, DriveSyncOutcome.synced);
    final folder = (await db.preferencesDao.current()).driveFolderId;
    expect(folder, isNot('folder0'));
    expect(drive.folders[folder], isFalse);
    expect(drive.docs, hasLength(1));
  });

  test('a 401 gets one fresh token and a second try', () async {
    final subject = await db.savedNotesDao.createFolder('Sítě');
    await lesson(subject, '- VLAN');
    drive.failNext('createFolder', const DriveAuthException('expired'));

    final report = await sync.syncAll();
    expect(report.outcome, DriveSyncOutcome.synced);
    expect(invalidated, 1);
  });

  test('a refused sign-in stops the run and asks to sign in again', () async {
    final subject = await db.savedNotesDao.createFolder('Sítě');
    await lesson(subject, '- VLAN');
    drive
      ..failNext('createFolder', const DriveAuthException('expired'))
      ..failNext('createFolder', const DriveAuthException('Přihlas se znovu.'));

    final report = await sync.syncAll();
    expect(report.outcome, DriveSyncOutcome.needsSignIn);
    expect(report.error, 'Přihlas se znovu.');
    expect(await db.driveDocsDao.doc(subject, DriveDocKind.notes), isNull);
  });

  test('offline: the doc is marked failed and the next run retries it',
      () async {
    final subject = await db.savedNotesDao.createFolder('Sítě');
    await lesson(subject, '- VLAN');
    drive.failNext('createFolder', const DriveTransientException());

    final report = await sync.syncAll();
    expect(report.outcome, DriveSyncOutcome.failed);
    final failed = await db.driveDocsDao.doc(subject, DriveDocKind.notes);
    expect(failed!.error, isNotNull);

    final retry = await sync.syncAll();
    expect(retry.uploaded, 1);
    expect(
      (await db.driveDocsDao.doc(subject, DriveDocKind.notes))!.error,
      isNull,
    );
  });

  test('a permanent failure on one subject does not stop the others',
      () async {
    final a = await db.savedNotesDao.createFolder('Angličtina');
    final b = await db.savedNotesDao.createFolder('Sítě');
    await lesson(a, '- words');
    await lesson(b, '- VLAN');
    drive.failNext('createDoc', const DrivePermanentException('Disk je plný.'));

    final report = await sync.syncAll();
    expect(report.outcome, DriveSyncOutcome.failed);
    expect(report.error, 'Disk je plný.');
    expect(report.uploaded, 1);
    expect(drive.docs, hasLength(1));
  });

  test('transcripts only when switched on, and only for finished lessons',
      () async {
    final subject = await db.savedNotesDao.createFolder('Sítě');
    await lesson(subject, '- VLAN');
    await lesson(subject, '- OSPF', ended: false);

    await sync.syncAll();
    expect(
      await db.driveDocsDao.doc(subject, DriveDocKind.transcripts),
      isNull,
    );

    await db.preferencesDao.setDriveIncludeTranscripts(true);
    final report = await sync.syncAll();
    expect(report.uploaded, 1);
    final row = await db.driveDocsDao.doc(subject, DriveDocKind.transcripts);
    final html = drive.docs[row!.docId]!;
    expect(html, contains('Dnes probereme směrování.'));
    expect('Hodina'.allMatches(html).length, greaterThanOrEqualTo(1));
    expect(drive.names[row.docId], contains('přepisy'));
  });
}
