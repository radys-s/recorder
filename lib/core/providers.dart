import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../ai/board_photo_service.dart';
import '../ai/card_digest_service.dart';
import '../ai/card_suggestions.dart';
import '../ai/card_lookup_service.dart';
import '../ai/photo_text_service.dart';
import '../ai/chat_answer_service.dart';
import '../ai/gemini_provider.dart';
import '../ai/groq_chat_provider.dart';
import '../ai/lesson_context_source.dart';
import '../ai/live_answer_service.dart';
import '../ai/llm_provider.dart';
import '../ai/notes_generator.dart';
import '../ai/web_answer_service.dart';
import '../audio/audio_capture_service.dart';
import '../audio/pcm_audio_source.dart';
import '../audio/wav_replay_audio_source.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/answer_cards_dao.dart';
import '../data/db/daos/chat_messages_dao.dart';
import '../data/db/daos/meeting_notes_dao.dart';
import '../data/db/daos/preferences_dao.dart';
import '../data/card_deleter.dart';
import '../data/secure/api_key_store.dart';
import '../queue/refined_transcript_service.dart';
import '../queue/transcription_queue_worker.dart';
import '../data/db/daos/refined_segments_dao.dart';
import '../stt/groq_whisper_stt_provider.dart';
import '../stt/refined_transcriber.dart';
import '../stt/stt_provider.dart';
import 'constants.dart';
import 'paths.dart';
import 'photo_picker.dart';

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
  final suggestions = ref.watch(cardSuggestionServiceProvider);
  return NotesGenerator(
    ref.watch(llmProvider),
    db.transcriptSegmentsDao,
    db.meetingNotesDao,
    refinedFor: db.refinedSegmentsDao.windows,
    lessonFor: ref.watch(lessonContextSourceProvider).notesInput,
    gemini: ref.watch(geminiProvider),
    hasGeminiKey: ref.watch(geminiKeyStoreProvider).hasKey,
    onLessonNotes: suggestions.suggest,
  );
});

/// Topics from a lesson's výpisky proposed as new cards.
final cardSuggestionServiceProvider = Provider<CardSuggestionService>((ref) {
  return CardSuggestionService(
    ref.watch(appDatabaseProvider),
    groq: ref.watch(llmProvider),
    gemini: ref.watch(geminiProvider),
    hasGeminiKey: ref.watch(geminiKeyStoreProvider).hasKey,
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
    lessonContext: ref.watch(lessonContextSourceProvider),
    gemini: ref.watch(geminiProvider),
    hasGeminiKey: ref.watch(geminiKeyStoreProvider).hasKey,
  );
});

/// What the student gave the AI for a lesson: rules, chat context, cards.
final lessonContextSourceProvider = Provider<LessonContextSource>((ref) {
  return LessonContextSource(ref.watch(appDatabaseProvider));
});

final chatMessagesDaoProvider = Provider<ChatMessagesDao>((ref) {
  return ref.watch(appDatabaseProvider).chatMessagesDao;
});

/// The lesson chat, watched, in recording order.
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, int>((ref, meetingId) {
  return ref.watch(chatMessagesDaoProvider).watchForMeeting(meetingId);
});

/// Questions typed into the lesson chat. The Gemini key is checked per
/// question, so adding or removing it in Settings applies to the next one.
final chatAnswerServiceProvider = Provider<ChatAnswerService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final geminiKeys = ref.watch(geminiKeyStoreProvider);
  return ChatAnswerService(
    ref.watch(llmProvider),
    db.chatMessagesDao,
    db.transcriptSegmentsDao,
    ref.watch(lessonContextSourceProvider),
    gemini: ref.watch(geminiProvider),
    hasGeminiKey: geminiKeys.hasKey,
    refinedFor: db.refinedSegmentsDao.windows,
  );
});

/// The optional second key, in its own Keychain slot.
final geminiKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => ApiKeyStore(storageKey: kGeminiApiKeyStorageKey),
);

final geminiProvider = Provider<GeminiProvider>((ref) {
  return GeminiProvider(ref.watch(geminiKeyStoreProvider));
});

final hasGeminiKeyProvider = FutureProvider<bool>((ref) {
  return ref.watch(geminiKeyStoreProvider).hasKey();
});

final maskedGeminiKeyProvider = FutureProvider<String?>((ref) {
  return ref.watch(geminiKeyStoreProvider).maskedKey();
});

/// Summaries and keywords for cards, made when a card is saved.
final cardDigestServiceProvider = Provider<CardDigestService>((ref) {
  final geminiKeys = ref.watch(geminiKeyStoreProvider);
  return CardDigestService(
    ref.watch(appDatabaseProvider).subjectsDao,
    groq: ref.watch(llmProvider),
    gemini: ref.watch(geminiProvider),
    hasGeminiKey: geminiKeys.hasKey,
  );
});

final photoPickerProvider = Provider<PhotoPicker>((ref) => PhotoPicker());

/// Page and board photos, read by Gemini.
final photoTextServiceProvider = Provider<PhotoTextService>((ref) {
  return PhotoTextService(ref.watch(geminiProvider));
});

final boardPhotoServiceProvider = Provider<BoardPhotoService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BoardPhotoService(
    db.chatMessagesDao,
    ref.watch(photoTextServiceProvider),
    readBytes: (stored) async =>
        File(await resolveStoredPath(stored)).readAsBytes(),
    subjectName: (meetingId) async {
      final meeting = await (db.select(db.meetings)
            ..where((t) => t.id.equals(meetingId)))
          .getSingleOrNull();
      final subjectId = meeting?.subjectId;
      return subjectId == null
          ? null
          : (await db.subjectsDao.subject(subjectId))?.name;
    },
  );
});

/// „Dohledat" in the card editor.
final cardLookupServiceProvider = Provider<CardLookupService>((ref) {
  return CardLookupService(
    gemini: ref.watch(geminiProvider),
    hasGeminiKey: ref.watch(geminiKeyStoreProvider).hasKey,
    web: ref.watch(webAnswerServiceProvider),
  );
});

final cardDeleterProvider = Provider<CardDeleter>((ref) {
  return CardDeleter(
    ref.watch(appDatabaseProvider).subjectsDao,
    documentsPath: documentsPath,
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
    // Names from the lesson's pinned cards, so Whisper spells them right.
    glossaryFor: (meetingId) =>
        ref.read(lessonContextSourceProvider).glossary(meetingId),
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

final refinedSegmentsDaoProvider = Provider<RefinedSegmentsDao>((ref) {
  return ref.watch(appDatabaseProvider).refinedSegmentsDao;
});

/// The refined windows of one meeting, in order.
final refinedSegmentsProvider =
    StreamProvider.family<List<RefinedSegment>, int>((ref, meetingId) {
  return ref.watch(refinedSegmentsDaoProvider).watchForMeeting(meetingId);
});

/// The second transcription pass after a recording. Resumed at app launch.
final refinedTranscriptServiceProvider =
    Provider<RefinedTranscriptService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final lessons = ref.watch(lessonContextSourceProvider);
  return RefinedTranscriptService(
    db,
    RefinedTranscriber(
      gemini: ref.watch(geminiProvider),
      stt: ref.watch(sttProvider),
    ),
    hasGeminiKey: ref.watch(geminiKeyStoreProvider).hasKey,
    resolvePath: resolveStoredPath,
    tempDir: getTemporaryDirectory,
    lessonInfo: (meetingId) async {
      final material = await lessons.load(meetingId);
      return (
        subjectName: material.subjectName,
        cardTitles: [
          for (final c in material.cards)
            if (c.pinned) c.title,
        ],
        glossary: await lessons.glossary(meetingId),
      );
    },
    waitForTurn: _waitUntilOnline,
  );
});

/// Returns once any network is up; checks again every 15 s.
Future<void> _waitUntilOnline() async {
  final connectivity = Connectivity();
  while (true) {
    try {
      final results = await connectivity.checkConnectivity();
      if (results.any((r) => r != ConnectivityResult.none)) return;
    } catch (_) {
      return; // Cannot tell: let the request fail and be retried.
    }
    await Future<void>.delayed(const Duration(seconds: 15));
  }
}

/// Whether a Groq key is stored. Screens watch this to show a "set your key"
/// hint; invalidate it after saving or clearing the key in Settings.
final hasApiKeyProvider = FutureProvider<bool>((ref) {
  return ref.watch(apiKeyStoreProvider).hasKey();
});

/// Masked form of the stored key, for display only.
final maskedApiKeyProvider = FutureProvider<String?>((ref) {
  return ref.watch(apiKeyStoreProvider).maskedKey();
});
