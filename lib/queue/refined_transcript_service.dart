import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../ai/llm_provider.dart';
import '../audio/wav_concat.dart';
import '../core/constants.dart';
import '../core/logging.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/refined_segments_table.dart';
import '../stt/refined_transcriber.dart';
import '../stt/refined_transcript.dart';
import '../stt/stt_provider.dart';
import '../stt/term_corrections.dart';

/// Lesson facts a window's request is told.
typedef RefinedLessonInfo = ({
  String? subjectName,
  String? courseLine,
  String? topicTitle,
  List<String> cardTitles,
  String? glossary,
  List<String> terms,
  List<String> slideTexts,
  List<String> contextMessages,
  List<TermCorrection> corrections,
});

/// The second transcription pass, run after a recording ends.
///
/// The live pass hears 8–20 s at a time with only the previous chunk's tail
/// as context, which is where cut words, wrong words and invented endings come
/// from. This pass hears the same audio again in windows of minutes — Gemini
/// when its key is set, Whisper otherwise — and its text replaces the live
/// text everywhere after the lesson.
///
/// One window at a time, oldest meeting first. Nothing here throws to the
/// caller: a window that keeps failing is marked failed, and the live text
/// stands in for it.
class RefinedTranscriptService {
  RefinedTranscriptService(
    this._db,
    this._transcriber, {
    required this.hasGeminiKey,
    required this.resolvePath,
    required this.tempDir,
    this.lessonInfo,
    this.waitForTurn,
    this.onMeetingReady,
    this.onPassFinished,
    this.retryDelays = kRefinedRetryDelays,
  });

  static const _tag = 'stt.refined';

  final AppDatabase _db;
  final RefinedTranscriber _transcriber;
  final Future<bool> Function() hasGeminiKey;
  final Future<String> Function(String stored) resolvePath;
  final Future<Directory> Function() tempDir;
  final Future<RefinedLessonInfo> Function(int meetingId)? lessonInfo;

  /// Awaited before every request, e.g. to wait out a missing connection.
  final Future<void> Function()? waitForTurn;

  /// Called after all refinement windows for one finished meeting settle.
  /// This deliberately runs after the second pass: notes should use the best
  /// text available, not race the live chunk transcription.
  final Future<void> Function(int meetingId)? onMeetingReady;

  /// Called once the queue runs dry. The audio cleanup hangs off this: a
  /// window that still has to be re-heard is the one thing that must not have
  /// its chunks deleted underneath it.
  final Future<void> Function()? onPassFinished;

  /// Pause before each further try; one try more than there are delays.
  final List<Duration> retryDelays;

  final _queue = Queue<int>();
  Future<void>? _running;

  /// Picks up windows a previous run did not finish.
  Future<void> resume() async {
    try {
      final reset = await _db.refinedSegmentsDao.resetRunning();
      if (reset > 0) AppLog.d(_tag, 'requeued $reset interrupted window(s)');
      final meetings = await _db.refinedSegmentsDao.meetingsWithPending();
      if (meetings.isEmpty) return;
      AppLog.d(_tag, 'resuming meetings $meetings');
      meetings.forEach(_enqueue);
      await _kick();
    } catch (e, st) {
      AppLog.e(_tag, 'resume failed', e, st);
    }
  }

  /// Plans what is left of a finished meeting and transcribes it.
  ///
  /// Windows already done during the lesson are kept, so stopping the
  /// recording only costs the tail. With [force] the meeting is planned from
  /// scratch and every window is transcribed again, which is what
  /// „Přepsat znovu" means.
  Future<void> refine(int meetingId, {bool force = false}) =>
      _plan(meetingId, live: false, force: force);

  /// Re-hears the windows that are already whole while the lesson is still
  /// running, so the student reads corrected text within minutes instead of
  /// after the bell. The chunk still being recorded is never part of a window,
  /// and live answers keep running on the raw live text.
  Future<void> refineWhileRecording(int meetingId) =>
      _plan(meetingId, live: true, force: false);

  Future<void> _plan(
    int meetingId, {
    required bool live,
    required bool force,
  }) async {
    try {
      final meeting = await (_db.select(
        _db.meetings,
      )..where((t) => t.id.equals(meetingId))).getSingleOrNull();
      if (meeting == null) return;
      if (live ? meeting.endedAt != null : meeting.endedAt == null) return;

      final segments = await _db.transcriptSegmentsDao.segmentsForMeeting(
        meetingId,
      );
      final gemini = await hasGeminiKey();
      final engine = gemini ? RefinedEngine.gemini : RefinedEngine.whisper;
      final plans = planWindows(
        segments,
        target: gemini ? kRefinedGeminiWindow : kRefinedWhisperWindow,
        includeTail: !live,
      );
      final dao = _db.refinedSegmentsDao;

      if (force) {
        await dao.replaceWindows(meetingId, [
          for (final w in plans)
            (startMs: w.startMs, endMs: w.endMs, engine: engine),
        ]);
        AppLog.d(
          _tag,
          'meeting $meetingId: ${plans.length} window(s) via ${engine.name}',
        );
        if (plans.isEmpty) return;
      } else {
        final existing = await dao.windows(meetingId);
        // Chunks only ever get appended, so the boundaries of the windows
        // already planned do not move; everything past the last one is new.
        final covered = existing.isEmpty
            ? 0
            : existing.map((w) => w.endMs).reduce((a, b) => a > b ? a : b);
        final fresh = [
          for (final w in plans)
            if (w.endMs > covered)
              (
                // A last window that swallowed a short tail can reach back
                // into covered audio; [chunksIn] goes by midpoint, so moving
                // the start forward is enough to keep the two from overlapping.
                startMs: w.startMs < covered ? covered : w.startMs,
                endMs: w.endMs,
                engine: engine,
              ),
        ];
        if (fresh.isEmpty) return;
        await dao.addWindows(meetingId, fresh);
        AppLog.d(
          _tag,
          'meeting $meetingId: ${fresh.length} new window(s) via '
          '${engine.name}${live ? ', lesson still running' : ''}',
        );
      }
      _enqueue(meetingId);
      await _kick();
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: could not plan', e, st);
    }
  }

  /// Tries one failed window again.
  Future<void> retryWindow(int windowId) async {
    try {
      final window = await _db.refinedSegmentsDao.window(windowId);
      if (window == null) return;
      await _db.refinedSegmentsDao.markPending(windowId);
      _enqueue(window.meetingId);
      await _kick();
    } catch (e, st) {
      AppLog.e(_tag, 'window $windowId: retry failed', e, st);
    }
  }

  void _enqueue(int meetingId) {
    if (!_queue.contains(meetingId)) _queue.add(meetingId);
  }

  /// Starts the drain unless it runs already; either way completes once the
  /// queue is empty.
  Future<void> _kick() =>
      _running ??= _drain().whenComplete(() => _running = null);

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      final meetingId = _queue.removeFirst();
      try {
        await _processMeeting(meetingId);
      } catch (e, st) {
        AppLog.e(_tag, 'meeting $meetingId: pass stopped', e, st);
      }
    }
    try {
      await onPassFinished?.call();
    } catch (e, st) {
      AppLog.e(_tag, 'after-pass step failed', e, st);
    }
  }

  Future<void> _processMeeting(int meetingId) async {
    // Re-read after every window: a retry or a re-plan changes what is left.
    while (true) {
      final windows = await _db.refinedSegmentsDao.windows(meetingId);
      final next = windows
          .where((w) => w.status == RefinedStatus.pending)
          .firstOrNull;
      if (next == null) {
        try {
          await onMeetingReady?.call(meetingId);
        } catch (e, st) {
          AppLog.e(
            _tag,
            'meeting $meetingId: after-refinement step failed',
            e,
            st,
          );
        }
        return;
      }
      await _processWindow(next, windows);
    }
  }

  Future<void> _processWindow(
    RefinedSegment window,
    List<RefinedSegment> all,
  ) async {
    final dao = _db.refinedSegmentsDao;
    await dao.markRunning(window.id);

    File? wav;
    try {
      final segments = await _db.transcriptSegmentsDao.segmentsForMeeting(
        window.meetingId,
      );
      final chunks = chunksIn(segments, window.startMs, window.endMs);
      final voiced = chunks.any((s) => s.voicedMs == null)
          ? null
          : chunks.fold<int>(0, (sum, s) => sum + s.voicedMs!);
      if (chunks.isEmpty || (voiced != null && voiced < kRefinedMinVoicedMs)) {
        // Nothing to hear: no request, and nothing to invent.
        await dao.markReady(window.id, '', window.engine);
        return;
      }

      final dir = await tempDir();
      wav = File(
        p.join(
          dir.path,
          'refined_${window.meetingId}_${window.windowIndex}_${DateTime.now().microsecondsSinceEpoch}.wav',
        ),
      );
      final joined = await concatWavFiles(
        inputs: [for (final c in chunks) await resolvePath(c.localAudioPath)],
        outputPath: wav.path,
      );
      if (joined.pcmBytes == 0) {
        await dao.markFailed(window.id, 'Zvuk této části chybí.');
        return;
      }

      final context = await _context(window, all);
      final engines = window.engine == RefinedEngine.gemini
          ? const [RefinedEngine.gemini, RefinedEngine.whisper]
          : const [RefinedEngine.whisper];
      final errors = <String>[];
      for (final engine in engines) {
        final outcome = await _tryEngine(
          engine,
          wav,
          context,
          voicedMs: voiced,
          durationMs: window.endMs - window.startMs,
        );
        var text = outcome.text;
        if (text != null) {
          if (text.isNotEmpty && context.corrections.isNotEmpty) {
            text = applyTermCorrections(text, context.corrections).text;
          }
          await dao.markReady(window.id, text, engine);
          AppLog.d(
            _tag,
            'window ${window.id}: ready via ${engine.name} (${text.length} chars)',
          );
          return;
        }
        errors.add(outcome.error ?? '');
      }
      final message = errors.where((e) => e.isNotEmpty).join(' · ');
      await dao.markFailed(window.id, message);
      AppLog.e(_tag, 'window ${window.id} failed: $message');
    } catch (e, st) {
      AppLog.e(_tag, 'window ${window.id} failed unexpectedly', e, st);
      await dao.markFailed(window.id, '$e');
    } finally {
      try {
        if (wav != null && await wav.exists()) await wav.delete();
      } catch (_) {}
    }
  }

  Future<({String? text, String? error})> _tryEngine(
    RefinedEngine engine,
    File wav,
    RefinedContext context, {
    required int? voicedMs,
    required int durationMs,
  }) async {
    var error = '';
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      if (attempt > 0) await Future<void>.delayed(retryDelays[attempt - 1]);
      await waitForTurn?.call();
      try {
        final text = switch (engine) {
          RefinedEngine.gemini => await _transcriber.viaGemini(wav, context),
          RefinedEngine.whisper => await _transcriber.viaWhisper(
            wav,
            context,
            voicedMs: voicedMs,
            durationMs: durationMs,
          ),
        };
        return (text: text, error: null);
      } on AiPermanentException catch (e) {
        return (text: null, error: e.message);
      } on SttPermanentException catch (e) {
        return (text: null, error: e.message);
      } on AiException catch (e) {
        error = e.message;
      } on SttException catch (e) {
        error = e.message;
      } catch (e) {
        // Unclassified (a disk error, a parsing bug): transient, but bounded.
        error = '$e';
      }
      AppLog.d(_tag, '${engine.name} try ${attempt + 1} failed: $error');
    }
    return (text: null, error: error);
  }

  Future<RefinedContext> _context(
    RefinedSegment window,
    List<RefinedSegment> all,
  ) async {
    final previous = all
        .where(
          (w) =>
              w.windowIndex < window.windowIndex &&
              w.status == RefinedStatus.ready &&
              (w.content?.trim().isNotEmpty ?? false),
        )
        .lastOrNull;
    final prefs = await _db.preferencesDao.current();
    RefinedLessonInfo? info;
    try {
      info = await lessonInfo?.call(window.meetingId);
    } catch (e, st) {
      AppLog.e(_tag, 'lesson info failed', e, st);
    }
    return RefinedContext(
      subjectName: info?.subjectName,
      courseLine: info?.courseLine,
      topicTitle: info?.topicTitle,
      cardTitles: info?.cardTitles ?? const [],
      glossary: info?.glossary,
      terms: info?.terms ?? const [],
      slideTexts: info?.slideTexts ?? const [],
      contextMessages: info?.contextMessages ?? const [],
      corrections: info?.corrections ?? const [],
      previousText: previous?.content,
      languageCode: prefs.transcriptLanguage.code,
      sensitivity: prefs.micSensitivity,
    );
  }
}
