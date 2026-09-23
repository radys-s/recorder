import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../core/listening_diagnostics.dart';
import '../core/paths.dart';
import '../core/providers.dart';
import '../core/sensitivity.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/preferences_table.dart';
import '../data/db/tables/transcript_segments_table.dart';
import '../data/db/tables/upload_queue_table.dart';
import 'audio_capture_service.dart';
import 'foreground_recording_service.dart';
import 'high_pass.dart';
import 'pcm_audio_source.dart';
import 'pcm_chunker.dart';
import 'pcm_gain.dart';
import 'pcm_stats.dart';
import 'wav_writer.dart';

/// What the UI needs to know about the current recording. Deliberately does
/// *not* carry the audio level — that changes several times a second and would
/// rebuild every listener; see [RecordingController.level].
@immutable
class RecordingState {
  const RecordingState({
    this.isRecording = false,
    this.meetingId,
    this.startedAt,
    this.isPaused = false,
    this.pausedAt,
    this.pausedDuration = Duration.zero,
    this.chunkCount = 0,
    this.totalBytes = 0,
    this.error,
    this.snrDb,
    this.weakSignal = false,
  });

  final bool isRecording;
  final int? meetingId;
  final DateTime? startedAt;

  /// The microphone is intentionally paused, not disconnected. Keeping this
  /// separate from [isRecording] lets the UI retain the same lesson and offer
  /// a real Continue action instead of pretending the lesson ended.
  final bool isPaused;
  final DateTime? pausedAt;
  final Duration pausedDuration;
  final int chunkCount;

  /// Bytes captured so far, as of the last closed chunk. Not updated per
  /// stream event: that is ten state changes a second, and every widget
  /// watching the whole state rebuilt on each of them.
  final int totalBytes;
  final String? error;

  /// How far speech stands out from the room, in dB; null until the first
  /// measurement of this lesson.
  final double? snrDb;

  /// The signal has been too weak for long enough to be worth saying so.
  final bool weakSignal;

  /// Active recording time at [now]. Exposed separately from [elapsed] so the
  /// pause accounting is deterministic in tests instead of depending on the
  /// wall clock that happens to run during a test frame.
  Duration elapsedAt(DateTime now) {
    final started = startedAt;
    if (started == null) return Duration.zero;
    final activePause = isPaused && pausedAt != null
        ? now.difference(pausedAt!)
        : Duration.zero;
    final elapsed = now.difference(started) - pausedDuration - activePause;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration get elapsed => elapsedAt(DateTime.now());

  RecordingState copyWith({
    bool? isRecording,
    int? meetingId,
    DateTime? startedAt,
    bool? isPaused,
    DateTime? pausedAt,
    Duration? pausedDuration,
    int? chunkCount,
    int? totalBytes,
    String? error,
    double? snrDb,
    bool? weakSignal,
    bool clearError = false,
    bool clearMeeting = false,
    bool clearPause = false,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      meetingId: clearMeeting ? null : (meetingId ?? this.meetingId),
      startedAt: clearMeeting ? null : (startedAt ?? this.startedAt),
      isPaused: clearMeeting ? false : (isPaused ?? this.isPaused),
      pausedAt: clearMeeting || clearPause ? null : (pausedAt ?? this.pausedAt),
      pausedDuration: clearMeeting
          ? Duration.zero
          : (pausedDuration ?? this.pausedDuration),
      chunkCount: chunkCount ?? this.chunkCount,
      totalBytes: totalBytes ?? this.totalBytes,
      error: clearError ? null : (error ?? this.error),
      snrDb: clearMeeting ? null : (snrDb ?? this.snrDb),
      weakSignal: clearMeeting ? false : (weakSignal ?? this.weakSignal),
    );
  }
}

/// Orchestrates a recording: microphone → chunker → WAV file → database row →
/// upload queue.
///
/// Everything here runs in the main isolate on purpose (see
/// [ForegroundRecordingService] for why). The controller's only job at the
/// network boundary is to enqueue; it never awaits an upload, so a dead
/// connection cannot slow capture down.
class RecordingController extends Notifier<RecordingState> {
  static const _tag = 'audio.controller';

  final _foregroundService = const ForegroundRecordingService();
  final _meter = PcmLevelMeter();

  /// Strips rumble and DC offset before anything measures or stores audio.
  final _highPass = HighPassFilter();

  /// Current RMS/peak, updated far more often than [state]. Listen to this
  /// alone for a level meter so the rest of the UI stays still.
  final level = ValueNotifier<({double rms, double peak})>((rms: 0, peak: 0));

  /// The source this recording was started with. Held rather than re-read on
  /// stop, because toggling the debug replay switch mid-recording would
  /// otherwise hand [stop] a different object than [start] opened.
  PcmAudioSource? _source;

  StreamSubscription<Uint8List>? _subscription;
  Timer? _levelTimer;
  PcmChunker? _chunker;
  String? _sessionDir;

  /// Kept beside [_sessionDir] so the database rows can name the chunk
  /// relative to it. See [toStoredPath] for why they must.
  String? _docsPath;
  int? _meetingId;
  int _totalBytes = 0;

  /// The sensitivity in force. Unlike the chunk profile it may change
  /// mid-recording — a quiet meeting is noticed while it is happening — so it
  /// is followed live through [_prefsSubscription].
  SensitivityProfile _profile = SensitivityProfile.medium;
  MicSensitivity? _sensitivity;
  ProviderSubscription<AsyncValue<Preference>>? _prefsSubscription;

  /// [start] and [stop] both await several platform calls before [state]
  /// says anything changed, so a double tap would otherwise open the
  /// microphone twice or flush and close the same meeting twice.
  bool _starting = false;
  bool _stopping = false;
  bool _pausing = false;
  DateTime? _pauseStarted;
  Duration _pausedDuration = Duration.zero;

  @override
  RecordingState build() {
    ref.onDispose(() {
      _levelTimer?.cancel();
      _subscription?.cancel();
      _prefsSubscription?.close();
      // The source is owned by audioSourceProvider, which disposes it itself.
      level.dispose();
    });
    return const RecordingState();
  }

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<void> toggle({String? title}) =>
      state.isRecording ? stop() : start(title: title);

  /// Pauses the microphone without ending the meeting. The current chunk is
  /// flushed after the source stops, so words already captured before the tap
  /// cannot be stranded in the chunker.
  Future<void> pause() async {
    if (!state.isRecording || state.isPaused || _pausing || _stopping) return;
    _pausing = true;
    try {
      await _source?.pause();
      _chunker?.flush();
      _levelTimer?.cancel();
      _levelTimer = null;
      level.value = (rms: 0, peak: 0);
      final pausedAt = DateTime.now();
      _pauseStarted = pausedAt;
      state = state.copyWith(
        isPaused: true,
        pausedAt: pausedAt,
        pausedDuration: _pausedDuration,
      );
      await _foregroundService.updateNotification(
        title: 'Nahrávání pozastaveno',
        text: 'Hodina zůstává otevřená. Klepni na Pokračovat.',
      );
      AppLog.d(_tag, 'meeting $_meetingId paused');
    } catch (e, st) {
      AppLog.e(_tag, 'failed to pause recording', e, st);
      state = state.copyWith(error: 'Nahrávání se nepodařilo pozastavit.');
    } finally {
      _pausing = false;
    }
  }

  /// Continues the same meeting after [pause]. Audio time resumes where the
  /// chunker left off; wall-clock time spent paused is excluded from the UI.
  Future<void> resume() async {
    if (!state.isRecording || !state.isPaused || _pausing || _stopping) return;
    _pausing = true;
    try {
      await _source?.resume();
      final started = _pauseStarted ?? state.pausedAt;
      if (started != null) {
        _pausedDuration += DateTime.now().difference(started);
      }
      _pauseStarted = null;
      _meter.reset();
      _highPass.reset();
      _levelTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        level.value = (rms: _meter.rms, peak: _meter.peak);
        _meter.reset();
      });
      state = state.copyWith(
        isPaused: false,
        pausedDuration: _pausedDuration,
        clearPause: true,
        clearError: true,
      );
      await _foregroundService.updateNotification(
        title: 'Nahrávání běží',
        text: 'Zvuk se ukládá a přepisuje.',
      );
      AppLog.d(_tag, 'meeting $_meetingId resumed');
    } catch (e, st) {
      AppLog.e(_tag, 'failed to resume recording', e, st);
      state = state.copyWith(error: 'V nahrávání se nepodařilo pokračovat.');
    } finally {
      _pausing = false;
    }
  }

  /// [subjectId], [cardIds] and [rules] come from the start sheet: the lesson's
  /// subject, the cards pinned for it, and rules for this lesson only.
  Future<void> start({
    String? title,
    int? subjectId,
    List<int> cardIds = const [],
    String? rules,
  }) async {
    if (state.isRecording || _starting || _stopping) return;
    _starting = true;
    state = state.copyWith(clearError: true);

    try {
      // Order matters: RECORD_AUDIO must already be granted before Android
      // will let a microphone-type foreground service start.
      final source = ref.read(audioSourceProvider);
      _source = source;
      final stream = await source.start();

      await _foregroundService.ensureNotificationPermission();
      final serviceStarted = await _foregroundService.start(
        title: 'Nahrávání běží',
        text: 'Zvuk se ukládá a přepisuje.',
      );
      if (!serviceStarted) {
        // Not fatal — capture works, it is just killable in the background.
        AppLog.e(
          _tag,
          'foreground service did not start; capture is unprotected',
        );
      }

      final startedAt = DateTime.now();
      final meetingId = await _db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: title ?? _defaultTitle(startedAt, lesson: subjectId != null),
          createdAt: startedAt,
          subjectId: Value(subjectId),
        ),
      );
      _meetingId = meetingId;
      if (subjectId != null && cardIds.isNotEmpty) {
        await _db.subjectsDao.pinCards(meetingId, cardIds);
      }
      if (rules != null) {
        await _db.subjectsDao.setMeetingRules(meetingId, rules);
      }

      final docs = await getApplicationDocumentsDirectory();
      _docsPath = docs.path;
      _sessionDir = meetingRecordingsDir(docs.path, meetingId);
      AppLog.d(_tag, 'meeting $meetingId, chunks in $_sessionDir');

      // The chunk profile is decided once, here, and holds for the whole
      // recording: the chunker is built with the stream and cutting the
      // remaining audio differently halfway through would put a seam in the
      // timeline. Toggling live answers mid-meeting therefore changes only
      // whether answers are generated, not how the audio is cut.
      final prefs = await _db.preferencesDao.current();
      final fast = prefs.liveAnswersEnabled;
      // A new recording measures its room from scratch.
      _calibrator = null;
      _quality = SignalQualityTracker();
      _sensitivity = null;
      _chunker = PcmChunker(
        onChunk: _onChunk,
        onFrameLevel: _onFrameLevel,
        minDuration: fast ? kFastChunkMinDuration : kChunkMinDuration,
        targetDuration: fast ? kFastChunkTargetDuration : kChunkTargetDuration,
        hardCapDuration: fast
            ? kFastChunkHardCapDuration
            : kChunkHardCapDuration,
      );
      AppLog.d(
        _tag,
        'chunk profile: ${fast ? 'fast (live answers)' : 'normal'}',
      );
      _applySensitivity(prefs.micSensitivity);
      _prefsSubscription = ref.listen(preferencesProvider, (_, next) {
        final sensitivity = next.valueOrNull?.micSensitivity;
        if (sensitivity != null) _applySensitivity(sensitivity);
      });
      _meter.reset();
      _highPass.reset();
      _totalBytes = 0;
      _pauseStarted = null;
      _pausedDuration = Duration.zero;

      _subscription = stream.listen(
        _onData,
        onError: (Object e, StackTrace st) {
          AppLog.e(_tag, 'stream error', e, st);
          state = state.copyWith(error: '$e');
        },
        onDone: () {
          AppLog.d(_tag, 'stream closed');
          // stop() cancels this subscription before closing the source, so
          // reaching here means the source ended on its own — a finished
          // replay file, or the platform dropping the mic. Either way the
          // recording is over, and the tail chunk still needs flushing.
          if (state.isRecording) unawaited(stop());
        },
      );

      _levelTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        level.value = (rms: _meter.rms, peak: _meter.peak);
        _meter.reset();
      });

      state = RecordingState(
        isRecording: true,
        meetingId: meetingId,
        startedAt: startedAt,
        pausedDuration: _pausedDuration,
      );
    } on MicrophonePermissionDeniedException {
      AppLog.e(_tag, 'microphone permission denied');
      await _abandonStart();
      state = state.copyWith(error: 'Přístup k mikrofonu byl zamítnut.');
    } catch (e, st) {
      AppLog.e(_tag, 'failed to start recording', e, st);
      await _abandonStart();
      state = state.copyWith(error: '$e');
    } finally {
      _starting = false;
    }
  }

  /// Undoes whatever a failed [start] got as far as. Without this a failure
  /// after the source opened — the database, the documents directory — left
  /// the microphone running with nothing reading it, the foreground
  /// notification up, and a meeting row that never ends.
  Future<void> _abandonStart() async {
    _levelTimer?.cancel();
    _levelTimer = null;
    _prefsSubscription?.close();
    _prefsSubscription = null;
    try {
      await _subscription?.cancel();
      await _source?.stop();
      await _foregroundService.stop();
    } catch (e, st) {
      AppLog.e(_tag, 'cleanup after a failed start failed too', e, st);
    }
    _subscription = null;
    _source = null;
    _chunker = null;

    final meetingId = _meetingId;
    _meetingId = null;
    if (meetingId != null) {
      try {
        await _db.meetingsDao.markEnded(meetingId, DateTime.now());
      } catch (e, st) {
        AppLog.e(_tag, 'could not close meeting $meetingId', e, st);
      }
    }
  }

  Future<void> stop() async {
    if (!state.isRecording || _stopping) return;
    _stopping = true;

    try {
      _levelTimer?.cancel();
      _levelTimer = null;
      _prefsSubscription?.close();
      _prefsSubscription = null;
      await _subscription?.cancel();
      _subscription = null;
      await _source?.stop();
      _source = null;
      await _foregroundService.stop();

      // Emits whatever partial chunk is still buffered, so the tail of the
      // meeting is not lost.
      _chunker?.flush();
      _chunker = null;

      final meetingId = _meetingId;
      if (meetingId != null) {
        await _db.meetingsDao.markEnded(meetingId, DateTime.now());
        unawaited(_refineWhenPersisted(meetingId));
      }
      _meetingId = null;
      _pauseStarted = null;
    } catch (e, st) {
      // The recording is over either way; a state stuck on "recording" would
      // leave the banner up with a stop button that does nothing.
      AppLog.e(_tag, 'error while stopping', e, st);
      state = state.copyWith(error: '$e');
    } finally {
      level.value = (rms: 0, peak: 0);
      _quality = null;
      state = state.copyWith(
        isRecording: false,
        totalBytes: _totalBytes,
        weakSignal: false,
        clearMeeting: true,
      );
      _stopping = false;
    }
    // The flushed tail chunk is still being written at this point, so the
    // counts here are "everything but the tail" by definition.
    AppLog.d(
      _tag,
      'stopped after ${state.totalBytes} bytes; ${state.chunkCount} chunks '
      'persisted so far, tail still landing',
    );
  }

  /// Starts the second transcription pass once the tail chunk is on disk.
  Future<void> _refineWhenPersisted(int meetingId) async {
    try {
      await Future.wait([..._persisting]);
    } catch (_) {
      // A failed write is logged where it happened; refine what did land.
    }
    await ref.read(refinedTranscriptServiceProvider).refine(meetingId);
  }

  DateTime? _lastCut;

  /// Closes the current chunk now so the last few seconds get transcribed
  /// without waiting for a pause — „Odpověz teď". At most once per
  /// [kAnswerNowCutDebounce]; returns whether a chunk was cut.
  bool cutNow() {
    final chunker = _chunker;
    if (!state.isRecording || chunker == null) return false;
    final now = DateTime.now();
    if (_lastCut != null && now.difference(_lastCut!) < kAnswerNowCutDebounce) {
      return false;
    }
    // Too little to be worth a request of its own; the previous chunk already
    // holds what was just said.
    if (chunker.bufferedDuration < kMinTranscribableDuration) return false;
    _lastCut = now;
    return chunker.cut();
  }

  /// Idempotent: the preferences stream re-emits on every unrelated setting,
  /// and a freshly built chunker needs the thresholds even when the setting
  /// itself did not change.
  void _applySensitivity(MicSensitivity sensitivity) {
    final changed = sensitivity != _sensitivity;
    _sensitivity = sensitivity;
    if (sensitivity == MicSensitivity.auto) {
      _calibrator ??= AutoCalibrator();
      _profile = _calibrator!.latest ?? SensitivityProfile.auto;
    } else {
      _calibrator = null;
      _profile = SensitivityProfile.of(sensitivity);
    }
    _setChunkerThresholds();
    if (changed) AppLog.d(_tag, 'sensitivity: ${sensitivity.name}');
  }

  /// Only present while the sensitivity is automatic.
  AutoCalibrator? _calibrator;

  /// Runs for every recording, automatic sensitivity or not: a manual setting
  /// does not make a distant teacher any louder.
  SignalQualityTracker? _quality;

  void _onFrameLevel(double rms) {
    if (_quality?.add(rms) ?? false) {
      final q = _quality!;
      AppLog.d(
        _tag,
        'signal ${q.weak ? 'weak' : 'recovered'}: '
        '${q.snrDb!.toStringAsFixed(1)} dB',
      );
      state = state.copyWith(weakSignal: q.weak, snrDb: q.snrDb);
    }
    final next = _calibrator?.add(rms);
    if (next == null) return;
    _profile = next;
    _setChunkerThresholds();
    AppLog.d(_tag, 'auto sensitivity: $next');
  }

  void _setChunkerThresholds() {
    _chunker
      ?..voicedRmsThreshold = _profile.voicedRmsThreshold
      ..silenceRmsThreshold = _profile.silenceRmsThreshold;
  }

  void _onData(Uint8List raw) {
    final bytes = _highPass.process(raw);
    _meter.addBytes(bytes);
    _totalBytes += bytes.length;
    _chunker?.addBytes(bytes);
  }

  /// Called synchronously by the chunker. The persistence work is async, but
  /// the chunk's frames are already detached from the chunker's buffer, so
  /// there is nothing for the next stream event to race with.
  /// Chunk writes still in flight; the refined pass waits for the tail.
  final Set<Future<void>> _persisting = {};

  /// File writes finish at different times. Chaining them prevents a later
  /// short chunk reaching the queue before an earlier long one, which would
  /// reverse the transcript context seen by live answers.
  Future<void> _persistTail = Future<void>.value();

  void _onChunk(PcmChunk chunk) {
    AppLog.d(_tag, 'chunk closed: $chunk');
    ref
        .read(listeningDiagnosticsProvider)
        .record(
          ListeningStage.capture,
          ListeningOutcome.progress,
          'audio_received',
          meetingId: _meetingId,
          sequence: chunk.sequence,
          metrics: {'bytes': chunk.byteLength, 'voiced_ms': chunk.voicedMs},
        );
    ref
        .read(listeningDiagnosticsProvider)
        .record(
          ListeningStage.chunk,
          ListeningOutcome.progress,
          'closed_${chunk.cutReason.name}',
          meetingId: _meetingId,
          sequence: chunk.sequence,
          metrics: {
            'duration_ms': chunk.duration.inMilliseconds,
            'voiced_ms': chunk.voicedMs,
          },
        );
    state = state.copyWith(totalBytes: _totalBytes);
    // The profile is captured now: the thresholds that measured this chunk
    // are the ones that should judge it.
    final meetingId = _meetingId;
    final pending = _persistTail = _persistTail
        .catchError((_) {})
        .then(
          (_) =>
              _persistChunk(chunk, meetingId, _sessionDir, _docsPath, _profile),
        );
    _persisting.add(pending);
    unawaited(
      pending.whenComplete(() {
        _persisting.remove(pending);
        // Whole windows are re-heard while the lesson runs, so the transcript
        // on screen catches up within minutes. stop() plans the rest.
        if (meetingId != null &&
            state.isRecording &&
            !_stopping &&
            _meetingId == meetingId) {
          unawaited(
            ref
                .read(refinedTranscriptServiceProvider)
                .refineWhileRecording(meetingId),
          );
        }
      }),
    );
  }

  Future<void> _persistChunk(
    PcmChunk chunk,
    int? meetingId,
    String? dir,
    String? docsPath,
    SensitivityProfile profile,
  ) async {
    if (meetingId == null || dir == null || docsPath == null) return;

    final name = 'chunk_${chunk.sequence.toString().padLeft(4, '0')}.wav';
    final path = p.join(dir, name);
    // The file is written to the absolute path; only what goes in the
    // database is relative.
    final storedPath = toStoredPath(docsPath, path);

    try {
      // A flushed tail can be a fraction of a second long. Sending that to
      // Whisper produces a hallucinated word, so it is recorded as an already
      // finished, empty segment instead of being queued.
      final tooShort = chunk.duration < kMinTranscribableDuration;
      // Room tone gets the same treatment: nothing in it for Whisper to
      // transcribe, and plenty for it to invent. See [kMinVoicedDuration].
      final noSpeech =
          chunk.voicedMs < profile.minVoicedDuration.inMilliseconds;
      final skip = tooShort || noSpeech;

      // Only audio that is going to Whisper is worth raising. The skipped
      // chunks keep their original level; the refined pass after the lesson
      // applies its own gain when it reads them.
      final gain = skip
          ? 1.0
          : speechGain(
              chunk.frames,
              chunk.voicedFrames,
              maxGain: profile.maxGain,
            );
      final file = await writeWavFile(
        path: path,
        pcmFrames: applyGain(chunk.frames, gain),
        pcmByteLength: chunk.byteLength,
      );
      final size = await file.length();

      // The segment row goes in regardless of network state — that is what
      // makes "transcript so far, mid-recording" work by construction.
      final segmentId = await _db.transcriptSegmentsDao.insertSegment(
        TranscriptSegmentsCompanion.insert(
          meetingId: meetingId,
          sequence: chunk.sequence,
          startMs: chunk.startMs,
          endMs: chunk.endMs,
          status: skip ? SegmentStatus.transcribed : SegmentStatus.pending,
          localAudioPath: storedPath,
          createdAt: DateTime.now(),
          voicedMs: Value(chunk.voicedMs),
          cutReason: Value(chunk.cutReason.name),
        ),
      );

      if (skip) {
        ref
            .read(listeningDiagnosticsProvider)
            .record(
              ListeningStage.capture,
              ListeningOutcome.rejected,
              tooShort ? 'too_short' : 'insufficient_voice',
              meetingId: meetingId,
              sequence: chunk.sequence,
              segmentId: segmentId,
              metrics: {
                'duration_ms': chunk.duration.inMilliseconds,
                'voiced_ms': chunk.voicedMs,
              },
            );
        state = state.copyWith(chunkCount: state.chunkCount + 1);
        AppLog.d(
          _tag,
          'chunk ${chunk.sequence} -> $name ($size B, '
          '${chunk.duration.inMilliseconds}ms, voiced ${chunk.voicedMs}ms) '
          '${tooShort ? 'too short' : 'no speech'}, not uploaded, '
          'segment $segmentId left empty',
        );
        return;
      }

      final now = DateTime.now();
      await _db.uploadQueueDao.enqueue(
        UploadQueueCompanion.insert(
          segmentId: segmentId,
          meetingId: meetingId,
          localFilePath: storedPath,
          status: QueueStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );

      ref
          .read(listeningDiagnosticsProvider)
          .record(
            ListeningStage.capture,
            ListeningOutcome.accepted,
            'enqueued',
            meetingId: meetingId,
            sequence: chunk.sequence,
            segmentId: segmentId,
            metrics: {
              'duration_ms': chunk.duration.inMilliseconds,
              'voiced_ms': chunk.voicedMs,
            },
          );

      AppLog.d(
        _tag,
        'chunk ${chunk.sequence} -> $name ($size B, ${chunk.duration.inMilliseconds}ms, '
        'voiced ${chunk.voicedMs}ms'
        '${gain == 1 ? '' : ', gain ×${gain.toStringAsFixed(1)}'}), '
        'segment $segmentId enqueued',
      );

      state = state.copyWith(chunkCount: state.chunkCount + 1);

      // The worker also watches the table, but poking it turns "within 5s"
      // into "now" for the common case.
      unawaited(ref.read(queueWorkerProvider).poke());
    } catch (e, st) {
      AppLog.e(_tag, 'failed to persist chunk ${chunk.sequence}', e, st);
      ref
          .read(listeningDiagnosticsProvider)
          .record(
            ListeningStage.capture,
            ListeningOutcome.failed,
            'persistence_error',
            meetingId: meetingId,
            sequence: chunk.sequence,
          );
      state = state.copyWith(error: 'chunk write failed: $e');
    }
  }

  static String _defaultTitle(DateTime at, {required bool lesson}) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${lesson ? 'Hodina' : 'Schůzka'} ${two(at.day)}.${two(at.month)}. '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

final recordingControllerProvider =
    NotifierProvider<RecordingController, RecordingState>(
      RecordingController.new,
    );
