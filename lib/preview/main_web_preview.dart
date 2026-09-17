import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../ai/llm_provider.dart';
import '../app.dart';
import '../audio/recording_controller.dart';
import '../core/providers.dart';
import '../data/db/app_database.dart';
import '../data/secure/api_key_store.dart';
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
        llmProvider.overrideWithValue(_FakeLlm()),
        recordingControllerProvider.overrideWith(
          () => _PreviewRecordingController(recordingId),
        ),
      ],
      child: const RecorderApp(),
    ),
  );
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
        const MeetingsCompanion(endedAt: Value(null), interrupted: Value(false)),
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
