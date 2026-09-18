import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../ai/syllabus_import_service.dart';
import '../ai/term_alias_service.dart';
import '../ai/ai_router.dart';
import '../ai/board_photo_service.dart';
import '../ai/card_digest_service.dart';
import '../ai/card_suggestions.dart';
import '../ai/card_lookup_service.dart';
import '../ai/photo_text_service.dart';
import '../ai/timetable_import.dart';
import '../ai/chat_answer_service.dart';
import '../ai/gemini_model_resolver.dart';
import '../ai/gemini_models.dart';
import '../ai/gemini_provider.dart';
import '../ai/groq_chat_provider.dart';
import '../ai/lesson_context_source.dart';
import '../ai/live_answer_service.dart';
import '../ai/llm_provider.dart';
import '../ai/notes_generator.dart';
import '../ai/openai_compatible_provider.dart';
import '../ai/vision_fallback.dart';
import '../ai/web_answer_service.dart';
import '../audio/audio_capture_service.dart';
import '../audio/pcm_audio_source.dart';
import '../audio/wav_replay_audio_source.dart';
import '../data/db/app_database.dart';
import '../data/db/daos/answer_cards_dao.dart';
import '../data/db/daos/chat_messages_dao.dart';
import '../data/db/daos/meeting_notes_dao.dart';
import '../data/db/daos/preferences_dao.dart';
import '../data/db/tables/subject_terms_table.dart';
import '../audio/recording_controller.dart';
import '../data/audio_cleaner.dart';
import '../data/card_deleter.dart';
import '../data/secure/api_key_store.dart';
import 'logging.dart';
import '../queue/refined_transcript_service.dart';
import '../queue/transcription_queue_worker.dart';
import '../data/db/daos/refined_segments_dao.dart';
import '../stt/groq_whisper_stt_provider.dart';
import '../stt/lesson_vocabulary.dart';
import '../stt/refined_transcriber.dart';
import '../stt/stt_provider.dart';
import '../stt/term_corrections.dart';
import '../stt/transcript_corrector.dart';
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

/// Extra text services, each in its own Keychain slot. The custom one is for
/// a school's own model: its address and model id are stored the same way.
final mistralKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => ApiKeyStore(storageKey: kMistralApiKeyStorageKey),
);
final cerebrasKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => ApiKeyStore(storageKey: kCerebrasApiKeyStorageKey),
);
final customAiKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => ApiKeyStore(storageKey: kCustomAiKeyStorageKey),
);
final customAiBaseUrlStoreProvider = Provider<ApiKeyStore>(
  (ref) => ApiKeyStore(storageKey: kCustomAiBaseUrlStorageKey),
);
final customAiModelStoreProvider = Provider<ApiKeyStore>(
  (ref) => ApiKeyStore(storageKey: kCustomAiModelStorageKey),
);

/// Cooldowns shared by both routers, so the corrector and the answers see
/// the same busy services.
final aiRouteHealthProvider = Provider<AiRouteHealth>((ref) => AiRouteHealth());

List<AiRoute> _aiRoutes(Ref ref, {String? reasoningEffort}) {
  final customModel = ref.watch(customAiModelStoreProvider);
  return [
    AiRoute(
      vendor: AiVendor.custom,
      provider: OpenAiCompatibleProvider(
        ref.watch(customAiKeyStoreProvider),
        vendor: 'Vlastní',
        baseUrl: ref.watch(customAiBaseUrlStoreProvider).read,
      ),
      models: (tier, _) async {
        final id = (await customModel.read())?.trim() ?? '';
        return tier == AiTier.vision || id.isEmpty ? const [] : [id];
      },
    ),
    AiRoute(
      vendor: AiVendor.cerebras,
      provider: OpenAiCompatibleProvider(
        ref.watch(cerebrasKeyStoreProvider),
        vendor: 'Cerebras',
        baseUrl: () async => kCerebrasBaseUrl,
        reasoningEffort: reasoningEffort,
      ),
      models: (tier, _) async =>
          tier == AiTier.vision ? const [] : kCerebrasModels,
      maxInputTokens: kCerebrasMaxInputTokens,
    ),
    AiRoute(
      vendor: AiVendor.mistral,
      provider: OpenAiCompatibleProvider(
        ref.watch(mistralKeyStoreProvider),
        vendor: 'Mistral',
        baseUrl: () async => kMistralBaseUrl,
      ),
      models: (tier, _) async => switch (tier) {
        AiTier.fast => kMistralFastModels,
        AiTier.strong => kMistralStrongModels,
        AiTier.vision => kMistralVisionModels,
      },
    ),
    AiRoute(
      vendor: AiVendor.groq,
      provider: GroqChatProvider(
        ref.watch(apiKeyStoreProvider),
        reasoningEffort: reasoningEffort,
      ),
      models: (tier, requested) async =>
          tier == AiTier.vision || requested.isEmpty ? const [] : [requested],
    ),
  ];
}

/// Every text request of the app: Groq, Cerebras, Mistral and a custom
/// service, whichever has a key and is not resting. One instance for the app.
final routedLlmProvider = Provider<RoutedLlmProvider>((ref) {
  return RoutedLlmProvider(
    routes: _aiRoutes(ref),
    health: ref.watch(aiRouteHealthProvider),
  );
});

/// The chat model, shared by notes, answers and cards.
final llmProvider = Provider<LlmProvider>(
  (ref) => ref.watch(routedLlmProvider),
);

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
    onLessonNotes: (meetingId, notes) async {
      // The terms the notes define join the subject's vocabulary.
      try {
        final meeting = await (db.select(
          db.meetings,
        )..where((t) => t.id.equals(meetingId))).getSingleOrNull();
        final subjectId = meeting?.subjectId;
        if (subjectId != null) {
          await db.subjectsDao.addTerms(
            subjectId,
            keyTermsFromNotes(notes),
            TermSource.notes,
          );
        }
      } catch (e, st) {
        AppLog.e(
          'ai.notes',
          'meeting $meetingId: learning terms failed',
          e,
          st,
        );
      }
      await suggestions.suggest(meetingId, notes);
    },
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
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, int>((
  ref,
  meetingId,
) {
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

/// Maps the app's Gemini model names to ids this key really offers.
final geminiModelResolverProvider = Provider<GeminiModelResolver>((ref) {
  final keys = ref.watch(geminiKeyStoreProvider);
  final prefs = ref.watch(preferencesDaoProvider);
  return GeminiModelResolver(
    listModels: () => listGeminiModels(keys),
    override: () async => (await prefs.current()).geminiModelOverride,
  );
});

final geminiProvider = Provider<GeminiProvider>((ref) {
  return GeminiWithVisionFallback(
    ref.watch(geminiKeyStoreProvider),
    models: ref.watch(geminiModelResolverProvider),
    router: ref.watch(routedLlmProvider),
  );
});

/// Whether any service can read a photo: Gemini, or Mistral behind it.
final hasVisionKeyProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(geminiKeyStoreProvider).hasKey() ||
      await ref.watch(mistralKeyStoreProvider).hasKey();
});

final hasGeminiKeyProvider = FutureProvider<bool>((ref) {
  return ref.watch(geminiKeyStoreProvider).hasKey();
});

final maskedGeminiKeyProvider = FutureProvider<String?>((ref) {
  return ref.watch(geminiKeyStoreProvider).maskedKey();
});

/// Summaries and keywords for cards, made when a card is saved.
/// Turns the subject's foreign terms into the forms Whisper mishears them as.
final termAliasServiceProvider = Provider<TermAliasService>((ref) {
  return TermAliasService(
    ref.watch(appDatabaseProvider).subjectsDao,
    ref.watch(llmProvider),
  );
});

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

/// Timetable screenshots, read by Gemini.
final timetableImportServiceProvider = Provider<TimetableImportService>((ref) {
  return TimetableImportService(ref.watch(geminiProvider));
});

/// Thematic plans: pasted, photographed or estimated from the course.
final syllabusImportServiceProvider = Provider<SyllabusImportService>((ref) {
  return SyllabusImportService(
    gemini: ref.watch(geminiProvider),
    llm: ref.watch(llmProvider),
    hasGeminiKey: ref.watch(geminiKeyStoreProvider).hasKey,
  );
});

final boardPhotoServiceProvider = Provider<BoardPhotoService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BoardPhotoService(
    db.chatMessagesDao,
    ref.watch(photoTextServiceProvider),
    readBytes: (stored) async =>
        File(await resolveStoredPath(stored)).readAsBytes(),
    subjectName: (meetingId) async {
      final meeting = await (db.select(
        db.meetings,
      )..where((t) => t.id.equals(meetingId))).getSingleOrNull();
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

/// Proofreads lesson chunks against the subject's vocabulary, on the small
/// model so it never spends the answer model's per-minute budget.
final transcriptCorrectorProvider = Provider<TranscriptCorrector>((ref) {
  return TranscriptCorrector(
    RoutedLlmProvider(
      routes: _aiRoutes(ref, reasoningEffort: 'low'),
      health: ref.watch(aiRouteHealthProvider),
    ),
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
    // The lesson's vocabulary, so Whisper and the corrector spell it right.
    listeningFor: (meetingId) =>
        ref.read(lessonContextSourceProvider).listening(meetingId),
    corrector: ref.watch(transcriptCorrectorProvider),
    onTermsUsed: (ids) =>
        ref.read(appDatabaseProvider).subjectsDao.bumpTermUses(ids),
    // Fired and forgotten: the worker is a pure STT queue and must not wait
    // on an LLM call, and a slow answer must never delay the next chunk's
    // transcription.
    onTranscribed: (segment, text) {
      unawaited(
        ref.read(liveAnswerServiceProvider).handleSegment(segment, text),
      );
    },
  );
  ref.onDispose(worker.stop);
  return worker;
});

/// Frees the chunk WAVs of lessons that are finished with them.
final audioCleanerProvider = Provider<AudioCleaner>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AudioCleaner(
    db.meetingsDao,
    db.preferencesDao,
    documentsPath: documentsPath,
    // The lesson being recorded writes into that directory right now.
    isRecording: (meetingId) {
      final state = ref.read(recordingControllerProvider);
      return state.isRecording && state.meetingId == meetingId;
    },
  );
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
final refinedTranscriptServiceProvider = Provider<RefinedTranscriptService>((
  ref,
) {
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
      final l = await lessons.listening(meetingId);
      return (
        subjectName: l?.subjectName,
        courseLine: l?.courseLine,
        topicTitle: l?.topicTitle,
        cardTitles: l?.cardTitles ?? const <String>[],
        glossary: l?.leadIn,
        terms: [for (final t in l?.terms ?? const <RankedTerm>[]) t.term],
        slideTexts: l?.slideTexts ?? const <String>[],
        contextMessages: l?.contextMessages ?? const <String>[],
        corrections: l?.corrections ?? const <TermCorrection>[],
      );
    },
    waitForTurn: _waitUntilOnline,
    // The pass is the last thing that needs the chunk files, so this is the
    // moment their retention clock is worth checking.
    onPassFinished: () => ref.read(audioCleanerProvider).sweep(),
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
