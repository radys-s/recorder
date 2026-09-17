import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/logging.dart';
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
    this.tick = const Duration(seconds: 5),
  }) : _connectivity = connectivity ?? Connectivity();

  static const _tag = 'queue.worker';

  final UploadQueueDao _queueDao;
  final TranscriptSegmentsDao _segmentsDao;
  final PreferencesDao _prefsDao;
  final SttProvider _stt;
  final Connectivity _connectivity;

  /// How often to re-check for rows whose backoff has elapsed.
  final Duration tick;

  /// Called after a segment's text is written, with the sanitized text.
  ///
  /// This is how live answering hangs off the transcript without the worker
  /// knowing anything about it: the callback is expected to return
  /// immediately (the wiring fires it with `unawaited`), so the drain loop
  /// never waits on an LLM call. A throw from it is caught here rather than
  /// killing the pass.
  final void Function(TranscriptSegment segment, String text)? onTranscribed;

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

  /// Resolves once every correction started so far has finished.
  Future<void> settle() => Future.wait(_corrections.toList());

  StreamSubscription<int>? _queueSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;

  bool _running = false;
  bool _draining = false;

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
    await _queueSub?.cancel();
    _queueSub = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;

    AppLog.d(_tag, 'stopped');
  }

  /// Runs one drain pass now. Safe to call at any time; overlapping calls
  /// collapse into the one already in flight.
  Future<void> poke() => _drain();

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
      while (_running) {
        final rows = await _queueDao.dueRows(DateTime.now());
        if (rows.isEmpty) break;

        for (final row in rows) {
          if (!_running) return;
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
      if (text != result.text.trim()) {
        AppLog.d(
          _tag,
          'row ${row.id} sanitized: ${_preview(result.text)} -> ${_preview(text)}',
        );
      }
      // A glossary is prompt too, and a silent chunk can come back as a list
      // of the lesson's names.
      if (isPromptEcho(text, prompt) ||
          isPromptEcho(text, [?glossary, ?prompt].join(' '))) {
        AppLog.d(_tag, 'row ${row.id}: prompt echo dropped: ${_preview(text)}');
        text = '';
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
      } else {
        await _segmentsDao.updateSegmentText(
          row.segmentId,
          text,
          SegmentStatus.transcribed,
          confidence: result.confidence,
          rawContent: heard,
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
    } on SttPermanentException catch (e) {
      await _park(row, e.message);
    } on SttTransientException catch (e) {
      await _scheduleRetry(row, attempt, e.message);
    } catch (e, st) {
      // An unclassified failure (a disk error, a bug in parsing) is treated as
      // transient: the attempt counter still bounds it, so it cannot spin.
      AppLog.e(_tag, 'row ${row.id} failed unexpectedly', e, st);
      await _scheduleRetry(row, attempt, '$e');
    }
  }

  /// Proofreads a lesson chunk, then hands the final text on. The transcript
  /// is already written, so the student never waits for this; live answers
  /// do, for at most the corrector's timeout.
  Future<void> _afterWrite(
    TranscriptSegment segment,
    String text, {
    required LessonListening? lesson,
    required String? previous,
    required double? confidence,
    required Set<int> used,
    required bool enabled,
  }) async {
    var finalText = text;
    final corrector = this.corrector;
    if (corrector != null &&
        lesson != null &&
        enabled &&
        !corrector.disabled &&
        lesson.subjectName != null &&
        text.trim().split(RegExp(r'\s+')).length >= 3) {
      try {
        final corrected = await corrector
            .correct(
              text: text,
              lesson: lesson,
              previous: [?previous],
              uncertain: isLowConfidence(confidence),
            )
            .timeout(corrector.timeout + const Duration(seconds: 1));
        if (corrected != null) {
          final current = await _segmentsDao.segmentById(segment.id);
          // The student may have fixed it by hand in the meantime.
          if (current?.content == text) {
            await _segmentsDao.correctSegment(segment.id, corrected);
            finalText = corrected;
            AppLog.d(
              _tag,
              'segment ${segment.id} corrected: ${_preview(text)} -> '
              '${_preview(corrected)}',
            );
          }
        }
      } catch (e) {
        AppLog.d(_tag, 'segment ${segment.id} correction skipped: $e');
      }
    }

    if (lesson != null) {
      used.addAll(termsMentioned(finalText, lesson.terms));
    }
    if (used.isNotEmpty && onTermsUsed != null) {
      try {
        await onTermsUsed!(used);
      } catch (e, st) {
        AppLog.e(_tag, 'term use count failed', e, st);
      }
    }

    // Words the recognizer barely believed are no ground for an answer
    // nobody asked for; the student can still ask.
    if (isVeryLowConfidence(confidence)) {
      AppLog.d(_tag, 'segment ${segment.id}: too uncertain to answer from');
      return;
    }
    try {
      onTranscribed?.call(segment, finalText);
    } catch (e, st) {
      AppLog.e(_tag, 'onTranscribed callback threw', e, st);
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

  Future<void> _park(UploadQueueData row, String error) async {
    await _queueDao.markFailedPermanent(row.id, error);
    await _segmentsDao.updateSegmentStatus(row.segmentId, SegmentStatus.failed);
    AppLog.e(_tag, 'row ${row.id} parked as permanently failed', error);
  }
}
