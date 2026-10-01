import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../ai/gemini_provider.dart';
import '../ai/llm_provider.dart';
import '../ai/timetable_import.dart';
import '../app.dart';
import '../audio/recording_controller.dart';
import '../core/photo_picker.dart';
import '../core/providers.dart';
import '../data/db/app_database.dart';
import '../data/db/tables/preferences_table.dart';
import '../data/secure/api_key_store.dart';
import '../learning/exam_prep.dart';
import '../legal/legal_texts.dart';
import 'demo_seed.dart';

/// Test-only web entry point for Playwright: demo data, fake keys, no network,
/// no microphone. Build with
/// `flutter build web -t lib/preview/main_web_preview.dart`.
///
/// `?scenario=fresh` starts empty with no keys, `full` seeds everything,
/// `recording` also pretends a lesson is being recorded.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  Intl.defaultLocale = 'cs';
  await initializeDateFormatting('cs');

  final scenario = Uri.base.queryParameters['scenario'] ?? 'full';
  final fresh = scenario == 'fresh';
  final db = AppDatabase();
  int? recordingId;
  if (!fresh) {
    final seeded = await seedDemo(db, recording: scenario == 'recording');
    recordingId = seeded.recording;
    // Seeded scenarios skip the consent screen; `?consent=1` shows it.
    if (Uri.base.queryParameters['consent'] != '1') {
      await db.preferencesDao.acceptTerms(kTermsVersion, DateTime.now());
    }
    await db.preferencesDao.setRecordingNoticeDismissed(true);
  }
  // `?accent=sapphire` previews another accent preset.
  final accent = Uri.base.queryParameters['accent'];
  for (final preset in AccentPreset.values) {
    if (preset.name == accent) await db.preferencesDao.setAccentPreset(preset);
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiKeyStoreProvider.overrideWithValue(
          _MemoryKeyStore(fresh ? null : 'gsk_test'),
        ),
        geminiKeyStoreProvider.overrideWithValue(
          _MemoryKeyStore(fresh ? null : 'AIza_test'),
        ),
        mistralKeyStoreProvider.overrideWithValue(
          _MemoryKeyStore(fresh ? null : 'm_test'),
        ),
        cerebrasKeyStoreProvider.overrideWithValue(_MemoryKeyStore(null)),
        customAiKeyStoreProvider.overrideWithValue(_MemoryKeyStore(null)),
        customAiBaseUrlStoreProvider.overrideWithValue(_MemoryKeyStore(null)),
        customAiModelStoreProvider.overrideWithValue(_MemoryKeyStore(null)),
        llmProvider.overrideWithValue(_FakeLlm()),
        // Nothing in the preview may reach Google.
        geminiProvider.overrideWith(
          (ref) => _FakeGemini(ref.read(geminiKeyStoreProvider)),
        ),
        examPrepServiceProvider.overrideWith(
          (ref) =>
              ExamPrepService(ref.watch(appDatabaseProvider), llm: _FakeLlm()),
        ),
        photoPickerProvider.overrideWithValue(_FakePicker()),
        timetableImportServiceProvider.overrideWith(
          (ref) => TimetableImportService(
            _FakeTimetableGemini(ref.read(geminiKeyStoreProvider)),
          ),
        ),
        recordingControllerProvider.overrideWith(
          () => _PreviewRecordingController(recordingId),
        ),
      ],
      child: const RecorderApp(),
    ),
  );
}

/// Hands back one tiny picture instead of opening the camera or gallery.
class _FakePicker extends PhotoPicker {
  static final _photo = PickedPhoto(
    bytes: Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]),
    mimeType: 'image/jpeg',
    extension: 'jpg',
  );

  @override
  Future<PickedPhoto?> takePhoto() async => _photo;

  @override
  Future<List<PickedPhoto>> pickPages() async => [_photo];
}

/// Answers every Gemini call with a short canned text, so a screen that
/// reaches for Gemini (card lookup, digests, výpisky) works without a network.
class _FakeGemini extends GeminiProvider {
  _FakeGemini(super.store);

  @override
  Future<GeminiCompletion> generate({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    bool search = false,
    bool jsonMode = false,
    int? maxTokens,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return GeminiCompletion(
      content: jsonMode ? '{}' : '- Ukázková odpověď náhledu.',
    );
  }
}

/// A canned timetable read, as Gemini would return it for a Bakaláři
/// screenshot: one subject the demo already has, new ones, a double lesson
/// and a period without times.
class _FakeTimetableGemini extends GeminiProvider {
  _FakeTimetableGemini(super.store);

  @override
  Future<GeminiCompletion> generate({
    required String model,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    bool search = false,
    bool jsonMode = false,
    int? maxTokens,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return const GeminiCompletion(
      content:
          '{"lessons":['
          '{"subject":"Čeština","day":1,"start":"8:00","end":"8:45"},'
          '{"subject":"Matematika","day":1,"start":"8:55","end":"9:40"},'
          '{"subject":"Matematika","day":1,"start":"10:00","end":"10:45"},'
          '{"subject":"Anglický jazyk","day":2,"start":"8:00","end":"8:45"},'
          '{"subject":"Dějepis","day":2,"period":2},'
          '{"subject":"Fyzika","day":3,"start":"11:50","end":"12:35"}]}',
    );
  }
}

class _MemoryKeyStore extends ApiKeyStore {
  _MemoryKeyStore(this._value);

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String key) async => _value = key.trim();

  @override
  Future<void> delete() async => _value = null;
}

class _FakeLlm extends LlmProvider {
  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (messages.first.content.startsWith('A student has a test soon')) {
      return const LlmCompletion(content: _examReply);
    }
    return LlmCompletion(
      content: jsonMode ? '{}' : '- Ukázková odpověď náhledu.',
    );
  }
}

/// Reports a running lesson with a moving level, without any audio.
class _PreviewRecordingController extends RecordingController {
  _PreviewRecordingController(this._initialMeeting);

  final int? _initialMeeting;
  Timer? _timer;

  @override
  RecordingState build() {
    super.build();
    ref.onDispose(() => _timer?.cancel());
    final id = _initialMeeting;
    if (id == null) return const RecordingState();
    // The app's startup closes every open meeting as interrupted, which is
    // right for a real launch but would mark this pretend lesson too.
    Timer(const Duration(seconds: 2), () {
      final db = ref.read(appDatabaseProvider);
      (db.update(db.meetings)..where((t) => t.id.equals(id))).write(
        const MeetingsCompanion(
          endedAt: Value(null),
          interrupted: Value(false),
        ),
      );
    });
    _tick();
    return RecordingState(
      isRecording: true,
      meetingId: id,
      startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    );
  }

  void _tick() {
    var t = 0.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      t += 0.1;
      final rms = 0.05 + 0.04 * math.sin(t * 3).abs();
      level.value = (rms: rms, peak: rms * 2);
    });
  }

  @override
  Future<void> start({
    String? title,
    int? subjectId,
    List<int> cardIds = const [],
    String? rules,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final id = await db.meetingsDao.insertMeeting(
      MeetingsCompanion.insert(
        title: title ?? 'Hodina teď',
        createdAt: DateTime.now(),
        subjectId: Value(subjectId),
      ),
    );
    _tick();
    state = RecordingState(
      isRecording: true,
      meetingId: id,
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    final id = state.meetingId;
    if (id != null) {
      final db = ref.read(appDatabaseProvider);
      await (db.update(db.meetings)..where((t) => t.id.equals(id))).write(
        MeetingsCompanion(endedAt: Value(DateTime.now())),
      );
    }
    state = const RecordingState();
  }

  @override
  bool cutNow() => false;
}

const _examReply = r"""
{"summary": "- Babička je próza, obrazy venkovského života.\n- Autorka: Božena Němcová.\n- Realismus: věrné zobrazení skutečnosti.",
 "questions": [
  {"q": "Kdo napsal Babičku?", "options": ["Karel Hynek Mácha", "Božena Němcová", "Jan Neruda", "Karel Havlíček"], "correct": 1,
   "explanation": "Babičku vydala Božena Němcová v roce 1855."},
  {"q": "Jaký literární druh je Babička?", "options": ["lyrika", "drama", "epika (próza)", "poezie"], "correct": 2,
   "explanation": "Je psaná souvislým textem, tedy próza."},
  {"q": "Jak se jmenuje dívka, která žije u splavu?", "a": "Viktorka",
   "explanation": "Viktorka je tragická postava u splavu."}
 ]}""";
