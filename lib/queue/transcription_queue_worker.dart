import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/redaction.dart';
import '../core/logging.dart';
import '../core/listening_diagnostics.dart';
import '../core/paths.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/preferences_dao.dart';
import '../data/db/daos/transcript_segments_dao.dart';
import '../data/db/daos/upload_queue_dao.dart';
import '../data/db/tables/transcript_segments_table.dart';
import '../stt/lesson_vocabulary.dart';
import '../stt/stt_provider.dart';
import '../stt/term_corrections.dart';
import '../stt/transcript_corrector.dart';
import '../stt/transcript_sanitizer.dart';
import '../stt/whisper_segment_filter.dart';
import 'backoff.dart';
import 'transcription_wait.dart';

/// Drains the upload queue, completely decoupled from recording.
///
/// The recorder never waits on this: it writes a WAV, inserts a segment row
/// and enqueues, and is done. Everything about network state, retries and
/// ordering lives here, which is why a dropout mid-meeting cannot stall or
/// pause capture.
///
/// Three things wake the worker, because none of them alone is enough:
///   * a table write (a chunk was just enqueued, or a row changed state),
///   * a periodic tick — drift streams don't re-fire just because a
///     `nextRetryAt` in the future has now passed,
///   * a connectivity-restored event, so a backlog drains the moment the
///     network returns instead of waiting out the remaining backoff.
class TranscriptionQueueWorker {
  /// The dependencies are positional because Dart has no way to spell a
  /// private field as a *named* initializing formal, and the lints would
  /// rather have the formal than the readability of names here.
  TranscriptionQueueWorker(
    this._queueDao,
    this._segmentsDao,
    this._prefsDao,
    this._stt, {
    Connectivity? connectivity,
    this.onTranscribed,
    this.listeningFor,
    this.corrector,
    this.onTermsUsed,
    this.diagnostics,
    this.tick = const Duration(seconds: 5),
    this.correctionFlushAfter = kCorrectionFlushAfter,
  }) : _connectivity = connectivity ?? Connectivity();

  static const _tag = 'queue.worker';

  final UploadQueueDao _queueDao;
  final TranscriptSegmentsDao _segmentsDao;
  final PreferencesDao _prefsDao;
  final SttProvider _stt;
  final Connectivity _connectivity;

  /// How often to re-check for rows whose backoff has elapsed.
  final Duration tick;

  /// How long a half-full proofreading batch waits for another chunk.
  final Duration correctionFlushAfter;
  Timer? _flushTimer;

  /// Called after a segment's text is written, with the sanitized text.
  ///
  /// This is how live answering hangs off the transcript without the worker
  /// knowing anything about it. A returned future is observed for failures,
  /// but never awaited: transcription must keep draining while an answer is
  /// being decided.
  final FutureOr<void> Function(TranscriptSegment segment, String text)?
  onTranscribed;

  /// Optional so focused queue tests do not need UI-level plumbing.
  final ListeningDiagnostics? diagnostics;

  /// What the lesson is about: the lead-in for Whisper's prompt, the
  /// corrections the student taught it and the words to spell right. A
  /// failure here costs only that help, never the chunk.
  final Future<LessonListening?> Function(int meetingId)? listeningFor;

  /// Proofreads a lesson chunk against its vocabulary after it is written.
  final TranscriptCorrector? corrector;

  /// Vocabulary rows that turned up in a transcript, to rank them higher.
  final Future<void> Function(Set<int> termIds)? onTermsUsed;

  /// Corrections still running, so tests can wait for them.
  final Set<Future<void>> _corrections = {};

  /// Chunks written and waiting for the next batched proofreading call.
  final List<_PendingCorrection> _pending = [];
  LessonListening? _pendingLesson;
  int? _pendingMeetingId;

  /// Resolves once every correction started so far has finished.
  Future<void> settle() async {
    await _flushCorrections();
    await Future.wait(_corrections.toList());
  }

  StreamSubscription<int>? _queueSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;

  bool _running = false;
  bool _draining = false;

  /// While set and in the future, nothing is sent: a 429 rests the whole
  /// queue, because every chunk behind the refused one would be refused too.
  DateTime? _pausedUntil;

  /// True while no engine has a key. Rows stay pending and no attempt is
  /// spent; saving a key ([keysChanged]) lifts it.
  bool _keyBlocked = false;

  bool get _resting =>
      _keyBlocked ||
      (_pausedUntil != null && _pausedUntil!.isAfter(DateTime.now()));

  /// When the queue will try again after a rate limit, if it is resting.
  DateTime? get pausedUntil => _resting ? _pausedUntil : null;

  /// Whether rows are waiting for a key rather than for time.
  bool get waitingForKey => _keyBlocked;

  final _waitChanges = StreamController<TranscriptionWait?>.broadcast();
  TranscriptionWait? _lastWait;
  Timer? _waitTimer;

  /// Why the queue is standing still, or null while it is working. The UI
  /// shows it so a student is not left looking at „Přepisuje se…" with no clue
  /// that a limit — not a fault — is what the chunks are waiting for.
  TranscriptionWait? get currentWait => _lastWait;

  /// Fires whenever [currentWait] changes, including when a pause runs out.
  Stream<TranscriptionWait?> get waitChanges => _waitChanges.stream;

  void _syncWait() {
    _waitTimer?.cancel();
    _waitTimer = null;
    final until = _pausedUntil;
    final TranscriptionWait? now;
    if (_keyBlocked) {
      now = const TranscriptionWait.missingKey();
    } else if (until != null && until.isAfter(DateTime.now())) {
      now = TranscriptionWait.rateLimit(until);
      // The pause has no event of its own when it ends; without this the
      // notice would outlive the limit until the next chunk was refused.
      _waitTimer = Timer(until.difference(DateTime.now()), () {
        _waitTimer = null;
        _syncWait();
        unawaited(_drain());
      });
    } else {
      now = null;
    }
    if (now == _lastWait) return;
    _lastWait = now;
    _waitChanges.add(now);
  }

  /// Starts true so the first event — which reports the current state, not a
  /// change — is not mistaken for a recovery.
  bool _wasOnline = true;

  bool get isRunning => _running;

  /// Starts the worker and immediately picks up whatever survived the last
  /// run — this is the auto-resume-after-restart behaviour.
  Future<void> start() async {
    if (_running) return;
    _running = true;

    final reset = await _queueDao.resetStuckUploads();
    if (reset > 0) {
      AppLog.d(
        _tag,
        'requeued $reset row(s) stranded as uploading by a previous run',
      );
    }

    _queueSub = _queueDao.watchOutstandingCount().listen((outstanding) {
      if (outstanding > 0) unawaited(_drain());
    });

    _timer = Timer.periodic(tick, (_) => unawaited(_drain()));

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      AppLog.d(_tag, 'connectivity changed: $results (online=$online)');

      final restored = online && !_wasOnline;
      _wasOnline = online;
      if (restored) unawaited(_resumeAfterOutage());
    });

    AppLog.d(_tag, 'started');
    unawaited(_drain());
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    _timer?.cancel();
    _timer = null;
    _waitTimer?.cancel();
    _waitTimer = null;
    await _queueSub?.cancel();
    _queueSub = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    unawaited(_flushCorrections());

    AppLog.d(_tag, 'stopped');
  }

  /// Runs one drain pass now. Safe to call at any time; overlapping calls
  /// collapse into the one already in flight.
  Future<void> poke() => _drain();

  /// A key was saved or removed. Lifts the waiting for a key and any pause,
  /// puts the chunks that failed because a key was refused back in line, and
  /// starts a pass.
  Future<void> keysChanged() async {
    _keyBlocked = false;
    _pausedUntil = null;
    _syncWait();
    final segmentIds = await _queueDao.requeueKeyFailures();
    for (final id in segmentIds) {
      await _segmentsDao.updateSegmentStatus(id, SegmentStatus.pending);
    }
    if (segmentIds.isNotEmpty) {
      AppLog.d(
        _tag,
        'requeued ${segmentIds.length} chunk(s) after a key change',
      );
    }
    await _drain();
  }

  /// The network came back. Every row waiting out a backoff was waiting for
  /// exactly this, so drop the remaining delay instead of making the user wait
  /// out a timer that is now measuring nothing.
  Future<void> _resumeAfterOutage() async {
    final cleared = await _queueDao.clearRetryBackoff();
    if (cleared > 0) {
      AppLog.d(_tag, 'network restored — retrying $cleared row(s) immediately');
    }
    await _drain();
  }

  /// Processes due rows one at a time, oldest first.
  ///
  /// Serial by design rather than a concurrency limit: an hour-long meeting is
  /// 120–180 chunks, and Groq's rate limiter is much happier with a steady
  /// single stream than with bursts. It also keeps transcripts arriving in
  /// order, which is what the live UI wants.
  Future<void> _drain() async {
    if (_draining || !_running) return;
    _draining = true;

    try {
      while (_running && !_resting) {
        final rows = await _queueDao.dueRows(DateTime.now());
        // An empty queue does not flush the batch: chunks arrive every ~10 s,
        // the queue is empty between each pair, and flushing there would make
        // every batch a single chunk. The batch has its own clock instead.
        if (rows.isEmpty) break;

        for (final row in rows) {
          if (!_running) return;
          if (_resting) break;
          await _process(row);
        }
        // Loop again: chunks finished while we were uploading are now due.
      }
    } catch (e, st) {
      // A failure here is in the queue plumbing itself, not in one upload —
      // the periodic tick will retry the whole pass.
      AppLog.e(_tag, 'drain pass failed', e, st);
    } finally {
      _draining = false;
    }
  }

  Future<void> _process(UploadQueueData row) async {
    final attempt = row.attemptCount + 1;
    AppLog.d(_tag, 'row ${row.id} (segment ${row.segmentId}) attempt $attempt');

    await _queueDao.markUploading(row.id);
    await _segmentsDao.updateSegmentStatus(
      row.segmentId,
      SegmentStatus.uploading,
    );
    diagnostics?.record(
      ListeningStage.transcription,
      ListeningOutcome.progress,
      'started',
      queueId: row.id,
      segmentId: row.segmentId,
      metrics: {'attempt': attempt},
    );

    try {
      final segment = await _segmentsDao.segmentById(row.segmentId);
      final prompt = segment == null
          ? null
          : await _segmentsDao.previousTranscript(
              segment.meetingId,
              segment.sequence,
            );

      // Read per row rather than once at start(): the user can change the
      // language mid-meeting, and the next chunk should honour it.
      final prefs = await _prefsDao.current();

      LessonListening? lesson;
      if (segment != null && listeningFor != null) {
        try {
          lesson = await listeningFor!(segment.meetingId);
        } catch (e, st) {
          AppLog.e(_tag, 'lesson vocabulary lookup failed', e, st);
        }
      }
      final glossary = lesson?.leadIn;

      final result = await _stt.transcribe(
        audioFile: File(await resolveStoredPath(row.localFilePath)),
        promptContext: prompt,
        languageCode: prefs.transcriptLanguage.code,
        sensitivity: prefs.micSensitivity,
        glossary: glossary,
        // The limits of the room the chunk was recorded in, not of whatever
        // the setting says by the time a backlog is uploaded.
        noSpeechProbThreshold: segment?.noSpeechThreshold,
        lowAvgLogprobThreshold: segment?.lowLogprobThreshold,
      );

      // Whisper answers silence with a plausible sentence rather than nothing,
      // and pinning the language above makes that more likely, not less.
      if (result.droppedSegments > 0) {
        AppLog.d(
          _tag,
          'row ${row.id}: dropped ${result.droppedSegments} low-confidence '
          'Whisper segment(s)',
        );
      }
      var text = sanitizeTranscript(result.text);
      if (segment != null) {
        text = limitToSpeakingRate(
          collapseRepeats(text),
          voicedMs: segment.voicedMs,
          durationMs: segment.endMs - segment.startMs,
        );
      }
      // The broad URL rule needs evidence from the recording itself. The
      // sanitizer has already removed known standalone artifacts; this second
      // pass only removes an arbitrary domain when Whisper was uncertain or
      // almost no voice reached the microphone.
      final urlFilter = filterTranscriptUrlArtifact(
        text,
        confidence: result.confidence,
        voicedMs: segment?.voicedMs,
        durationMs: segment == null ? null : segment.endMs - segment.startMs,
      );
      text = urlFilter.text;
      if (text != result.text.trim()) {
        AppLog.d(
          _tag,
          'row ${row.id} sanitized: ${_preview(result.text)} -> ${_preview(text)}',
        );
      }
      // A glossary is prompt too, and a silent chunk can come back as a list
      // of the lesson's names.
      var promptEcho = false;
      if (isPromptEcho(text, prompt) ||
          isPromptEcho(text, [?glossary, ?prompt].join(' '))) {
        AppLog.d(_tag, 'row ${row.id}: prompt echo dropped: ${_preview(text)}');
        text = '';
        promptEcho = true;
      }

      // A word the student already fixed once is fixed again, for free.
      String? heard;
      final used = <int>{};
      if (lesson != null && text.isNotEmpty && lesson.corrections.isNotEmpty) {
        final fixed = applyTermCorrections(text, lesson.corrections);
        if (fixed.applied.isNotEmpty) {
          heard = text;
          text = fixed.text;
          for (final i in fixed.applied) {
            used.add(lesson.correctionIds[i]);
          }
        }
      }

      if (text.isEmpty) {
        // Same path a sub-500ms tail takes: the segment stays in the timeline
        // so the sequence has no hole, it just has no text to show.
        await _segmentsDao.updateSegmentStatus(
          row.segmentId,
          SegmentStatus.transcribed,
        );
        diagnostics?.record(
          ListeningStage.transcription,
          ListeningOutcome.rejected,
          promptEcho ? 'prompt_echo' : (urlFilter.reason ?? 'transcript_empty'),
          meetingId: row.meetingId,
          queueId: row.id,
          segmentId: row.segmentId,
        );
      } else {
        await _segmentsDao.updateSegmentText(
          row.segmentId,
          text,
          SegmentStatus.transcribed,
          confidence: result.confidence,
          rawContent: heard,
          sttEngine: result.engine,
        );
        diagnostics?.record(
          ListeningStage.transcription,
          ListeningOutcome.accepted,
          'transcript_written',
          meetingId: row.meetingId,
          queueId: row.id,
          segmentId: row.segmentId,
          metrics: {'chars': text.length, 'confidence': result.confidence},
        );
      }
      await _queueDao.markSucceeded(row.id);

      if (segment != null && text.isNotEmpty) {
        final correction = _afterWrite(
          segment,
          text,
          lesson: lesson,
          previous: prompt,
          confidence: result.confidence,
          used: used,
          enabled: prefs.contextCorrection,
        );
        _corrections.add(correction);
        unawaited(
          correction.whenComplete(() => _corrections.remove(correction)),
        );
      }

      AppLog.d(
        _tag,
        'row ${row.id} transcribed (${text.length} chars, lang=${prefs.transcriptLanguage.code ?? 'auto'}/${result.language})',
      );
    } on SttRateLimited catch (e) {
      // Not a fault of this chunk and not an attempt: everything behind it
      // would be refused too, so the whole queue rests for as long as the
      // service asked.
      final wait = _pauseFor(e.retryAfter);
      _pausedUntil = DateTime.now().add(wait);
      _syncWait();
      await _queueDao.release(row.id);
      await _segmentsDao.updateSegmentStatus(
        row.segmentId,
        SegmentStatus.pending,
      );
      diagnostics?.record(
        ListeningStage.transcription,
        ListeningOutcome.progress,
        'rate_limited',
        meetingId: row.meetingId,
        queueId: row.id,
        segmentId: row.segmentId,
        metrics: {'pause_s': wait.inSeconds},
      );
      AppLog.w(_tag, 'rate limited — queue rests for ${wait.inSeconds}s');
    } on SttKeyMissing {
      _keyBlocked = true;
      _syncWait();
      await _queueDao.release(row.id);
      await _segmentsDao.updateSegmentStatus(
        row.segmentId,
        SegmentStatus.pending,
      );
      diagnostics?.record(
        ListeningStage.transcription,
        ListeningOutcome.progress,
        'waiting_for_key',
        meetingId: row.meetingId,
        queueId: row.id,
        segmentId: row.segmentId,
      );
      AppLog.w(_tag, 'no transcription key — rows wait, no attempt spent');
    } on SttPermanentException catch (e) {
      diagnostics?.record(
        ListeningStage.transcription,
        ListeningOutcome.failed,
        'transcription_failed',
        meetingId: row.meetingId,
        queueId: row.id,
        segmentId: row.segmentId,
      );
      final keyRefused = e.statusCode == 401 || e.statusCode == 403;
      await _park(row, keyRefused ? '$kKeyErrorTag ${e.message}' : e.message);
    } on SttTransientException catch (e) {
      diagnostics?.record(
        ListeningStage.transcription,
        ListeningOutcome.failed,
        'transcription_retry',
        meetingId: row.meetingId,
        queueId: row.id,
        segmentId: row.segmentId,
        metrics: {'attempt': attempt},
      );
      await _scheduleRetry(row, attempt, e.message);
    } catch (e, st) {
      // An unclassified failure (a disk error, a bug in parsing) is treated as
      // transient: the attempt counter still bounds it, so it cannot spin.
      AppLog.e(_tag, 'row ${row.id} failed unexpectedly', e, st);
      diagnostics?.record(
        ListeningStage.transcription,
        ListeningOutcome.failed,
        'processing_error',
        meetingId: row.meetingId,
        queueId: row.id,
        segmentId: row.segmentId,
        metrics: {'attempt': attempt},
      );
      await _scheduleRetry(row, attempt, describeError(e));
    }
  }

  /// Hands the written text on, then queues it for proofreading.
  ///
  /// The order is the point. The deterministic fixes — the student's own
  /// corrections and the subject's heard aliases — are already in [text] and
  /// cost nothing, so the live answer runs on them straight away. The AI pass
  /// happens later, in batches, and only rewrites what is stored; making an
  /// answer wait for it would be the opposite of what it is for.
  Future<void> _afterWrite(
    TranscriptSegment segment,
    String text, {
    required LessonListening? lesson,
    required String? previous,
    required double? confidence,
    required Set<int> used,
    required bool enabled,
  }) async {
    if (lesson != null) {
      used.addAll(termsMentioned(text, lesson.terms));
    }
    if (used.isNotEmpty && onTermsUsed != null) {
      try {
        await onTermsUsed!(used);
      } catch (e, st) {
        AppLog.e(_tag, 'term use count failed', e, st);
      }
    }

    _enqueueCorrection(
      segment,
      text,
      lesson: lesson,
      previous: previous,
      confidence: confidence,
      enabled: enabled,
    );

    // Words the recognizer barely believed are no ground for an answer
    // nobody asked for; the student can still ask.
    if (isVeryLowConfidence(confidence)) {
      AppLog.d(_tag, 'segment ${segment.id}: too uncertain to answer from');
      diagnostics?.record(
        ListeningStage.candidate,
        ListeningOutcome.rejected,
        'stt_confidence_below_threshold',
        meetingId: segment.meetingId,
        sequence: segment.sequence,
        segmentId: segment.id,
        metrics: {'confidence': confidence},
      );
      return;
    }
    try {
      final result = onTranscribed?.call(segment, text);
      if (result is Future<void>) {
        unawaited(
          result.catchError((Object e, StackTrace st) {
            AppLog.e(_tag, 'onTranscribed callback failed', e, st);
            diagnostics?.record(
              ListeningStage.candidate,
              ListeningOutcome.failed,
              'processing_error',
              meetingId: segment.meetingId,
              sequence: segment.sequence,
              segmentId: segment.id,
            );
          }),
        );
      }
    } catch (e, st) {
      AppLog.e(_tag, 'onTranscribed callback threw', e, st);
      diagnostics?.record(
        ListeningStage.candidate,
        ListeningOutcome.failed,
        'processing_error',
        meetingId: segment.meetingId,
        sequence: segment.sequence,
        segmentId: segment.id,
      );
    }
  }

  /// Adds a chunk to the batch waiting to be proofread, if it is worth it.
  void _enqueueCorrection(
    TranscriptSegment segment,
    String text, {
    required LessonListening? lesson,
    required String? previous,
    required double? confidence,
    required bool enabled,
  }) {
    final corrector = this.corrector;
    if (corrector == null ||
        lesson == null ||
        !enabled ||
        corrector.disabled ||
        lesson.subjectName == null ||
        text.trim().split(RegExp(r'\s+')).length < 3) {
      return;
    }
    // One request must never mix two lessons: the vocabulary and the course
    // belong to the meeting, not to the batch.
    if (_pending.isNotEmpty && _pendingMeetingId != segment.meetingId) {
      unawaited(_flushCorrections());
    }
    _pendingMeetingId = segment.meetingId;
    _pendingLesson = lesson;
    _pending.add(_PendingCorrection(segment, text, previous, confidence));
    if (_pending.length >= kCorrectionBatchSize) {
      unawaited(_flushCorrections());
    } else {
      // A batch that never fills — the end of a lesson, a pause between two —
      // still has to go out, but only after chunks had a fair chance to join.
      _flushTimer ??= Timer(correctionFlushAfter, () {
        _flushTimer = null;
        unawaited(_flushCorrections());
      });
    }
  }

  /// Sends whatever is waiting as one request. Resolves when it is done.
  Future<void> _flushCorrections() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return Future.value();
    final batch = List.of(_pending);
    final lesson = _pendingLesson!;
    _pending.clear();
    _pendingLesson = null;
    _pendingMeetingId = null;

    final run = _correctBatch(batch, lesson);
    _corrections.add(run);
    unawaited(run.whenComplete(() => _corrections.remove(run)));
    return run;
  }

  Future<void> _correctBatch(
    List<_PendingCorrection> batch,
    LessonListening lesson,
  ) async {
    final corrector = this.corrector;
    if (corrector == null || corrector.disabled) return;
    try {
      final corrected = await corrector
          .correctBatch(
            texts: [for (final p in batch) p.text],
            lesson: lesson,
            previous: [?batch.first.previous],
            uncertain: batch.any((p) => isLowConfidence(p.confidence)),
          )
          .timeout(corrector.timeout + const Duration(seconds: 1));
      final used = <int>{};
      for (var i = 0; i < batch.length && i < corrected.length; i++) {
        final text = corrected[i];
        if (text == null) continue;
        final pending = batch[i];
        final current = await _segmentsDao.segmentById(pending.segment.id);
        // The student may have fixed it by hand in the meantime.
        if (current?.content != pending.text) continue;
        await _segmentsDao.correctSegment(pending.segment.id, text);
        // A word only the correction spelled right still counts as a word this
        // lesson used, and ranking it is the whole point of counting.
        used.addAll(termsMentioned(text, lesson.terms));
        AppLog.d(
          _tag,
          'segment ${pending.segment.id} corrected: '
          '${_preview(pending.text)} -> ${_preview(text)}',
        );
      }
      if (used.isNotEmpty && onTermsUsed != null) {
        await onTermsUsed!(used);
      }
    } catch (e) {
      AppLog.d(_tag, 'correction of ${batch.length} chunk(s) skipped: $e');
    }
  }

  Future<void> _scheduleRetry(
    UploadQueueData row,
    int attempt,
    String error,
  ) async {
    if (attempt >= kMaxRetryAttempts) {
      await _park(row, 'gave up after $attempt attempts: $error');
      return;
    }

    final delay = retryDelay(attempt);
    await _queueDao.markFailedRetryable(
      row.id,
      attempt,
      DateTime.now().add(delay),
      error,
    );
    // Back to pending, not failed: the UI should show this chunk as still
    // coming, because it is.
    await _segmentsDao.updateSegmentStatus(
      row.segmentId,
      SegmentStatus.pending,
    );
    AppLog.d(
      _tag,
      'row ${row.id} retry $attempt in ${delay.inSeconds}s — $error',
    );
  }

  /// Short, single-line form for the log — a transcript chunk is far too long
  /// to print whole.
  static String _preview(String text) {
    final flat = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (flat.isEmpty) return '(empty)';
    return flat.length <= 60 ? '"$flat"' : '"${flat.substring(0, 60)}…"';
  }

  /// How long a 429 rests the queue: what the service said, else a minute,
  /// but never less than a second or more than ten minutes.
  static Duration _pauseFor(Duration? retryAfter) {
    final wait = retryAfter ?? const Duration(seconds: 60);
    if (wait < const Duration(seconds: 1)) return const Duration(seconds: 1);
    if (wait > const Duration(minutes: 10)) return const Duration(minutes: 10);
    return wait;
  }

  Future<void> _park(UploadQueueData row, String error) async {
    await _queueDao.markFailedPermanent(row.id, error);
    await _segmentsDao.updateSegmentStatus(row.segmentId, SegmentStatus.failed);
    AppLog.e(_tag, 'row ${row.id} parked as permanently failed', error);
  }
}

/// How many chunks one proofreading request covers.
///
/// Three is about forty seconds of speech: enough context for the model to
/// tell a misheard term from a word the teacher really said, and a third of
/// the requests a chunk-at-a-time pass would spend on the same rate limit.
const int kCorrectionBatchSize = 3;

/// How long a batch that is not full waits before it is sent anyway.
const Duration kCorrectionFlushAfter = Duration(seconds: 45);

/// A written chunk waiting for the next proofreading request.
class _PendingCorrection {
  _PendingCorrection(this.segment, this.text, this.previous, this.confidence);

  final TranscriptSegment segment;
  final String text;
  final String? previous;
  final double? confidence;
}
