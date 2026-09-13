import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/groq_chat_provider.dart';
import '../ai/live_answer_service.dart';
import '../ai/llm_provider.dart';
import '../ai/notes_generator.dart';
import '../ai/web_answer_service.dart';
import '../audio/audio_capture_service.dart';
import '../audio/pcm_audio_source.dart';
import '../audio/wav_replay_audio_source.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/answer_cards_dao.dart';
import '../data/db/daos/meeting_notes_dao.dart';
import '../data/db/daos/preferences_dao.dart';
import '../data/secure/api_key_store.dart';
import '../queue/transcription_queue_worker.dart';
import '../stt/groq_whisper_stt_provider.dart';
import '../stt/stt_provider.dart';
import 'constants.dart';

/// App-scoped singletons that outlive any single screen. The drift database
/// has its own provider in `data/db/app_database.dart`.

/// The one navigator. The recording banner is mounted above it, from
/// `MaterialApp.builder`, so it has no route context of its own and
/// `Navigator.of` would find nothing — this key is how it navigates.
final appNavigatorKey = GlobalKey<NavigatorState>();

final apiKeyStoreProvider = Provider<ApiKeyStore>((ref) => ApiKeyStore());

final preferencesDaoProvider = Provider<PreferencesDao>((ref) {
  return ref.watch(appDatabaseProvider).preferencesDao;
});

/// The settings row, watched. Screens read this; code outside the widget tree
/// takes [PreferencesDao] directly, the way the queue worker already takes the
/// other DAOs.
final preferencesProvider = StreamProvider<Preference>((ref) {
  return ref.watch(preferencesDaoProvider).watch();
});

/// Development-only: replay a WAV instead of opening the microphone.
///
/// Not persisted, because nothing that uses it needs to survive a restart, and
/// a flag that silently outlives a debugging session is a trap. Both flags are
/// ignored outside debug builds.
final replayAudioEnabledProvider = StateProvider<bool>((ref) => false);
final replayAudioLoopProvider = StateProvider<bool>((ref) => false);

/// Where the recording pipeline gets its audio. Swapping the implementation
/// here rather than inside the controller keeps the replay path identical to
/// the microphone path in every respect that matters.
final audioSourceProvider = Provider<PcmAudioSource>((ref) {
  final PcmAudioSource source;
  if (kDebugMode && ref.watch(replayAudioEnabledProvider)) {
    source = WavReplayAudioSource(
      candidateFileNames: kReplayAudioFileNames,
      loop: ref.watch(replayAudioLoopProvider),
    );
  } else {
    source = AudioCaptureService();
  }
  ref.onDispose(source.dispose);
  return source;
});

final meetingNotesDaoProvider = Provider<MeetingNotesDao>((ref) {
  return ref.watch(appDatabaseProvider).meetingNotesDao;
});

/// The chat model, shared by notes and (later) live answers. Stateless apart
/// from its Dio client, so one instance for the whole app is enough.
final llmProvider = Provider<LlmProvider>((ref) {
  return GroqChatProvider(ref.watch(apiKeyStoreProvider));
});

final notesGeneratorProvider = Provider<NotesGenerator>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return NotesGenerator(
    ref.watch(llmProvider),
    db.transcriptSegmentsDao,
    db.meetingNotesDao,
  );
});

final answerCardsDaoProvider = Provider<AnswerCardsDao>((ref) {
  return ref.watch(appDatabaseProvider).answerCardsDao;
});

/// The second hop of live answering, when the meeting cannot answer the
/// question itself. Same client and same key as every other Groq call — the
/// search happens server-side inside the completion.
final webAnswerServiceProvider = Provider<WebAnswerService>((ref) {
  return WebAnswerService(ref.watch(llmProvider));
});

/// Live answering. Reads the enabled flags itself, per segment, so the app-bar
/// toggle takes effect on the next chunk rather than the next meeting.
final liveAnswerServiceProvider = Provider<LiveAnswerService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LiveAnswerService(
    ref.watch(llmProvider),
    db.transcriptSegmentsDao,
    db.answerCardsDao,
    db.preferencesDao,
    ref.watch(webAnswerServiceProvider),
  );
});

final sttProvider = Provider<SttProvider>((ref) {
  return GroqWhisperSttProvider(ref.watch(apiKeyStoreProvider));
});

/// The single queue worker for the whole app. Created lazily but started
/// eagerly at app launch, because starting it is what resumes any chunks that
/// a previous run left unsent.
final queueWorkerProvider = Provider<TranscriptionQueueWorker>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final worker = TranscriptionQueueWorker(
    db.uploadQueueDao,
    db.transcriptSegmentsDao,
    db.preferencesDao,
    ref.watch(sttProvider),
    // Fired and forgotten: the worker is a pure STT queue and must not wait
    // on an LLM call, and a slow answer must never delay the next chunk's
    // transcription.
    onTranscribed: (segment, text) {
      unawaited(ref.read(liveAnswerServiceProvider).handleSegment(segment, text));
    },
  );
  ref.onDispose(worker.stop);
  return worker;
});

/// Whether a Groq key is stored. Screens watch this to show a "set your key"
/// hint; invalidate it after saving or clearing the key in Settings.
final hasApiKeyProvider = FutureProvider<bool>((ref) {
  return ref.watch(apiKeyStoreProvider).hasKey();
});

/// Masked form of the stored key, for display only.
final maskedApiKeyProvider = FutureProvider<String?>((ref) {
  return ref.watch(apiKeyStoreProvider).maskedKey();
});
