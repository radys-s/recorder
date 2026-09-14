import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../core/paths.dart';
import '../core/providers.dart';
import '../core/sensitivity.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/preferences_table.dart';
import '../data/db/tables/transcript_segments_table.dart';
import '../data/db/tables/upload_queue_table.dart';
import 'audio_capture_service.dart';
import 'foreground_recording_service.dart';
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
    this.chunkCount = 0,
    this.totalBytes = 0,
    this.error,
  });

  final bool isRecording;
  final int? meetingId;
  final DateTime? startedAt;
  final int chunkCount;

  /// Bytes captured so far, as of the last closed chunk. Not updated per
  /// stream event: that is ten state changes a second, and every widget
  /// watching the whole state rebuilt on each of them.
  final int totalBytes;
  final String? error;

  Duration get elapsed =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  RecordingState copyWith({
    bool? isRecording,
    int? meetingId,
    DateTime? startedAt,
    int? chunkCount,
    int? totalBytes,
    String? error,
    bool clearError = false,
    bool clearMeeting = false,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      meetingId: clearMeeting ? null : (meetingId ?? this.meetingId),
      startedAt: clearMeeting ? null : (startedAt ?? this.startedAt),
      chunkCount: chunkCount ?? this.chunkCount,
      totalBytes: totalBytes ?? this.totalBytes,
      error: clearError ? null : (error ?? this.error),
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

  Future<void> start({String? title}) async {
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
        AppLog.e(_tag, 'foreground service did not start; capture is unprotected');
      }

      final startedAt = DateTime.now();
      final meetingId = await _db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: title ?? _defaultTitle(startedAt),
          createdAt: startedAt,
        ),
      );
      _meetingId = meetingId;

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
      _chunker = PcmChunker(
        onChunk: _onChunk,
        minDuration: fast ? kFastChunkMinDuration : kChunkMinDuration,
        targetDuration: fast ? kFastChunkTargetDuration : kChunkTargetDuration,
        hardCapDuration:
            fast ? kFastChunkHardCapDuration : kChunkHardCapDuration,
      );
      AppLog.d(_tag, 'chunk profile: ${fast ? 'fast (live answers)' : 'normal'}');
      _applySensitivity(prefs.micSensitivity);
      _prefsSubscription = ref.listen(preferencesProvider, (_, next) {
        final sensitivity = next.valueOrNull?.micSensitivity;
        if (sensitivity != null) _applySensitivity(sensitivity);
      });
      _meter.reset();
      _totalBytes = 0;

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
      }
      _meetingId = null;
    } catch (e, st) {
      // The recording is over either way; a state stuck on "recording" would
      // leave the banner up with a stop button that does nothing.
      AppLog.e(_tag, 'error while stopping', e, st);
      state = state.copyWith(error: '$e');
    } finally {
      level.value = (rms: 0, peak: 0);
      state = state.copyWith(isRecording: false, totalBytes: _totalBytes);
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

  /// Idempotent: the preferences stream re-emits on every unrelated setting,
  /// and a freshly built chunker needs the thresholds even when the setting
  /// itself did not change.
  void _applySensitivity(MicSensitivity sensitivity) {
    final changed = sensitivity != _sensitivity;
    _sensitivity = sensitivity;
    _profile = SensitivityProfile.of(sensitivity);
    _chunker
      ?..voicedRmsThreshold = _profile.voicedRmsThreshold
      ..silenceRmsThreshold = _profile.silenceRmsThreshold;
    if (changed) AppLog.d(_tag, 'sensitivity: ${sensitivity.name}');
  }

  void _onData(Uint8List bytes) {
    _meter.addBytes(bytes);
    _totalBytes += bytes.length;
    _chunker?.addBytes(bytes);
  }

  /// Called synchronously by the chunker. The persistence work is async, but
  /// the chunk's frames are already detached from the chunker's buffer, so
  /// there is nothing for the next stream event to race with.
  void _onChunk(PcmChunk chunk) {
    AppLog.d(_tag, 'chunk closed: $chunk');
    state = state.copyWith(totalBytes: _totalBytes);
    // The profile is captured now: the thresholds that measured this chunk
    // are the ones that should judge it.
    unawaited(
      _persistChunk(chunk, _meetingId, _sessionDir, _docsPath, _profile),
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
      final noSpeech = chunk.voicedMs < profile.minVoicedDuration.inMilliseconds;
      final skip = tooShort || noSpeech;

      // Only audio that is going to Whisper is worth raising, and only on the
      // high setting — see [SensitivityProfile.maxGain].
      final gain =
          skip ? 1.0 : normalizingGain(chunk.frames, maxGain: profile.maxGain);
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
        ),
      );

      if (skip) {
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
      state = state.copyWith(error: 'chunk write failed: $e');
    }
  }

  static String _defaultTitle(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Schůzka ${two(at.day)}.${two(at.month)}. '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

final recordingControllerProvider =
    NotifierProvider<RecordingController, RecordingState>(RecordingController.new);
