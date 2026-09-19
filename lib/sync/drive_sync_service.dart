import 'dart:async';

import 'package:drift/drift.dart';

import '../ai/course_profile.dart';
import '../ai/lesson_context_source.dart';
import '../ai/syllabus.dart';
import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/drive_docs_table.dart';
import '../stt/refined_transcript.dart';
import 'drive_api.dart';
import 'drive_doc.dart';
import 'google_auth.dart' show GoogleSignInException;

enum DriveSyncOutcome {
  /// Every doc that needed it was uploaded (possibly none).
  synced,

  /// Nobody is signed in; nothing was tried.
  notSignedIn,

  /// Google refused the sign-in; the student has to sign in again.
  needsSignIn,

  /// At least one doc failed; the rest may have gone through.
  failed,
}

class DriveSyncReport {
  const DriveSyncReport(
    this.outcome, {
    this.uploaded = 0,
    this.skipped = 0,
    this.error,
  });

  final DriveSyncOutcome outcome;
  final int uploaded;

  /// Docs whose content had not changed since the last upload.
  final int skipped;

  /// A sentence for the student when something went wrong.
  final String? error;
}

/// One Google Doc as it should look now.
class _Doc {
  const _Doc(this.subjectId, this.kind, this.name, this.html);
  final int subjectId;
  final DriveDocKind kind;
  final String name;
  final String html;
}

/// Mirrors every subject into Google Docs in a „Schůzky" Drive folder, so
/// NotebookLM can use them as sources: one doc with the výpisky, and when
/// the student wants it, one with the transcripts.
///
/// Only what changed is uploaded — the doc's hash is kept — and an update
/// keeps the doc's id, so the NotebookLM source stays the same file.
class DriveSyncService {
  DriveSyncService(
    this._db, {
    required this._api,
    required this._invalidateAccessToken,
    Future<void> Function()? waitUntilOnline,
    DateTime Function()? now,
    this._debounce = kDriveSyncDebounce,
    this._retryDelay = const Duration(seconds: 30),
  }) : _waitUntilOnline = waitUntilOnline ?? (() async {}),
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DriveApi _api;
  final void Function() _invalidateAccessToken;
  final Future<void> Function() _waitUntilOnline;
  final DateTime Function() _now;
  final Duration _debounce;
  final Duration _retryDelay;

  Future<void> _tail = Future.value();
  StreamSubscription<Set<TableUpdate>>? _changes;
  Timer? _timer;
  bool _retryPending = false;
  bool _disposed = false;

  /// The folder checked during the current run, so it is looked up once.
  String? _runFolder;

  /// Starts syncing on its own: once shortly after launch, then after every
  /// change to what the docs are made of, when the student turned it on.
  void start() {
    _changes ??= _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.meetingNotes,
            _db.savedNotes,
            _db.subjects,
            _db.meetings,
            _db.refinedSegments,
            _db.chatMessages,
            _db.answerCards,
          ]),
        )
        .listen((_) => _schedule());
    _schedule();
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_auto()));
  }

  Future<void> _auto() async {
    if (_disposed) return;
    try {
      final prefs = await _db.preferencesDao.current();
      if (!prefs.driveSyncEnabled || prefs.googleAccountEmail == null) return;
      await syncAll();
    } catch (e, st) {
      AppLog.e('drive', 'automatic sync failed', e, st);
    }
  }

  /// Uploads every doc that changed; [force] uploads them all. Runs one at a
  /// time — a second call waits for the first.
  Future<DriveSyncReport> syncAll({bool force = false}) {
    final run = _tail.then((_) => _syncAll(force));
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<DriveSyncReport> _syncAll(bool force) async {
    final prefs = await _db.preferencesDao.current();
    if (prefs.googleAccountEmail == null) {
      return const DriveSyncReport(DriveSyncOutcome.notSignedIn);
    }
    _runFolder = null;
    final docs = await _collect(prefs);
    var uploaded = 0;
    var skipped = 0;
    String? firstError;

    for (final doc in docs) {
      final existing = await _db.driveDocsDao.doc(doc.subjectId, doc.kind);
      final hash = contentHash(doc.name, doc.html);
      if (!force &&
          existing?.docId != null &&
          existing!.contentHash == hash &&
          existing.error == null) {
        skipped++;
        continue;
      }
      try {
        final id = await _upload(doc, existing?.docId);
        await _db.driveDocsDao.markSynced(
          doc.subjectId,
          doc.kind,
          docId: id,
          hash: hash,
          at: _now(),
        );
        uploaded++;
      } on DriveAuthException catch (e) {
        AppLog.d('drive', 'sign-in refused: ${e.message}');
        return DriveSyncReport(
          DriveSyncOutcome.needsSignIn,
          uploaded: uploaded,
          skipped: skipped,
          error: e.message,
        );
      } on DriveTransientException catch (e) {
        await _db.driveDocsDao.markFailed(doc.subjectId, doc.kind, e.message);
        _retryLater();
        return DriveSyncReport(
          DriveSyncOutcome.failed,
          uploaded: uploaded,
          skipped: skipped,
          error: e.message,
        );
      } on GoogleSignInException catch (e) {
        await _db.driveDocsDao.markFailed(doc.subjectId, doc.kind, e.message);
        return DriveSyncReport(
          DriveSyncOutcome.failed,
          uploaded: uploaded,
          skipped: skipped,
          error: e.message,
        );
      } on DriveException catch (e) {
        // Permanent or a doc that keeps disappearing: this doc stays failed,
        // the others may still go through.
        AppLog.d('drive', 'doc ${doc.subjectId}/${doc.kind.name}: ${e.message}');
        await _db.driveDocsDao.markFailed(doc.subjectId, doc.kind, e.message);
        firstError ??= e.message;
      } catch (e, st) {
        AppLog.e('drive', 'unexpected sync failure', e, st);
        const message = 'Synchronizace se nepodařila. Zkus to znovu.';
        await _db.driveDocsDao.markFailed(doc.subjectId, doc.kind, message);
        return DriveSyncReport(
          DriveSyncOutcome.failed,
          uploaded: uploaded,
          skipped: skipped,
          error: message,
        );
      }
    }
    AppLog.d('drive', 'sync done: $uploaded uploaded, $skipped unchanged');
    return DriveSyncReport(
      firstError == null ? DriveSyncOutcome.synced : DriveSyncOutcome.failed,
      uploaded: uploaded,
      skipped: skipped,
      error: firstError,
    );
  }

  /// Updates the doc in place, or creates it when it is new or gone.
  Future<String> _upload(_Doc doc, String? docId) async {
    if (docId != null) {
      try {
        await _authed(
          () => _api.updateDoc(docId, name: doc.name, html: doc.html),
        );
        return docId;
      } on DriveNotFoundException {
        // Deleted or binned in Drive: start a new doc.
        await _db.driveDocsDao.forget(doc.subjectId, doc.kind);
      }
    }
    try {
      final folder = await _folder();
      return await _authed(
        () => _api.createDoc(name: doc.name, folderId: folder, html: doc.html),
      );
    } on DriveNotFoundException {
      // The folder went away between the check and the upload.
      await _forgetFolder();
      final folder = await _folder();
      return _authed(
        () => _api.createDoc(name: doc.name, folderId: folder, html: doc.html),
      );
    }
  }

  Future<String> _folder() async {
    final checked = _runFolder;
    if (checked != null) return checked;
    final known = (await _db.preferencesDao.current()).driveFolderId;
    if (known != null) {
      if (await _authed(() => _api.folderExists(known))) {
        return _runFolder = known;
      }
      await _forgetFolder();
    }
    final id = await _authed(() => _api.createFolder(kDriveFolderName));
    await _db.preferencesDao.setDriveFolderId(id);
    return _runFolder = id;
  }

  /// The folder is gone, and the docs in it went with it.
  Future<void> _forgetFolder() async {
    _runFolder = null;
    await _db.preferencesDao.setDriveFolderId(null);
    await _db.driveDocsDao.forgetAll();
  }

  /// A 401 usually means the access token expired early; one fresh token
  /// is worth a second try.
  Future<T> _authed<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DriveAuthException {
      _invalidateAccessToken();
      return call();
    }
  }

  void _retryLater() {
    if (_retryPending || _disposed) return;
    _retryPending = true;
    unawaited(() async {
      try {
        await _waitUntilOnline();
        await Future<void>.delayed(_retryDelay);
      } finally {
        _retryPending = false;
      }
      await _auto();
    }());
  }

  /// Every doc the subjects should have right now.
  Future<List<_Doc>> _collect(Preference prefs) async {
    final docs = <_Doc>[];
    final source = LessonContextSource(_db);
    for (final summary in await _db.subjectsDao.allSubjects()) {
      final subject = summary.subject;
      final name = subject.fullName?.trim().isNotEmpty ?? false
          ? subject.fullName!.trim()
          : subject.name;
      final course = courseLine(subject, prefs);
      final topics = await _db.subjectsDao.topics(subject.id);
      final meetings =
          await (_db.select(_db.meetings)
                ..where((t) => t.subjectId.equals(subject.id))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();

      final lessons = <DocLesson>[];
      final transcripts = <DocTranscript>[];
      for (final m in meetings) {
        final topic = lessonTopic(m, topics)?.title;
        final notes = (await _db.meetingNotesDao.forMeeting(
          m.id,
        ))?.content?.trim();
        if (notes != null && notes.isNotEmpty) {
          final input = await source.notesInput(m.id);
          lessons.add(
            DocLesson(
              date: m.createdAt,
              topic: topic,
              notes: notes,
              important: input?.important ?? const [],
              questions: input?.questions ?? const [],
            ),
          );
        }
        if (prefs.driveIncludeTranscripts && m.endedAt != null) {
          final text = refinedOrLiveTranscript(
            await _db.transcriptSegmentsDao.segmentsForMeeting(m.id),
            await _db.refinedSegmentsDao.windows(m.id),
          );
          if (text.trim().isNotEmpty) {
            transcripts.add(
              DocTranscript(date: m.createdAt, topic: topic, text: text),
            );
          }
        }
      }

      final saved =
          await (_db.select(_db.savedNotes)
                ..where(
                  (t) => t.folderId.equals(subject.id) & t.meetingId.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();
      final notes = [
        for (final n in saved)
          if (n.content.trim().isNotEmpty)
            DocNote(title: n.title, content: n.content),
      ];

      if (lessons.isNotEmpty || notes.isNotEmpty) {
        docs.add(
          _Doc(
            subject.id,
            DriveDocKind.notes,
            notesDocName(name),
            notesDocHtml(
              subject: name,
              courseLine: course,
              lessons: lessons,
              notes: notes,
            ),
          ),
        );
      }
      if (transcripts.isNotEmpty) {
        docs.add(
          _Doc(
            subject.id,
            DriveDocKind.transcripts,
            transcriptsDocName(name),
            transcriptsDocHtml(
              subject: name,
              courseLine: course,
              lessons: transcripts,
            ),
          ),
        );
      }
    }
    return docs;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_changes?.cancel());
  }
}
