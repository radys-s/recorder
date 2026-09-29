import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/pcm_audio_source.dart';
import 'package:recorder/audio/recording_controller.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/core/storage_info.dart';
import 'package:recorder/data/db/app_database.dart';

const _bytesPerMs = 32;

Uint8List _loud(int ms) {
  final bytes = Uint8List(ms * _bytesPerMs);
  for (var i = 0; i < bytes.length ~/ 2; i++) {
    final sample = i.isEven ? 6000 : -6000;
    final unsigned = sample < 0 ? sample + 0x10000 : sample;
    bytes[i * 2] = unsigned & 0xFF;
    bytes[i * 2 + 1] = (unsigned >> 8) & 0xFF;
  }
  return bytes;
}

/// A microphone the test drives by hand.
class _FakeSource implements PcmAudioSource {
  _FakeSource({this.throwOnStop = false, this.earlyBytes});

  final bool throwOnStop;

  /// Delivered right after start(), before the controller is set up.
  final Uint8List? earlyBytes;

  StreamController<Uint8List> controller = StreamController<Uint8List>();
  int pauses = 0;
  int restarts = 0;

  void emit(Uint8List bytes) => controller.add(bytes);

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<Stream<Uint8List>> start() async {
    final early = earlyBytes;
    if (early != null) scheduleMicrotask(() => controller.add(early));
    return controller.stream;
  }

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async {}

  @override
  Future<Stream<Uint8List>> restart() async {
    restarts++;
    await controller.close();
    controller = StreamController<Uint8List>();
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    if (throwOnStop) throw StateError('platform said no');
  }

  @override
  Future<void> dispose() async {}
}

class _FixedStorage extends StorageInfo {
  const _FixedStorage(this.free);
  final int? free;
  @override
  Future<int?> freeBytes() async => free;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late Directory docs;
  late AppDatabase db;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('recording_controller_test');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await db.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  ProviderContainer container(_FakeSource source, {int? freeBytes}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioSourceProvider.overrideWithValue(source),
        storageInfoProvider.overrideWithValue(_FixedStorage(freeBytes)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  /// stop() returns while the tail chunk is still being written and the second
  /// pass is being planned; the container must outlive both.
  Future<void> stopAndDrain(RecordingController controller) async {
    await controller.stop();
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  test('a paused lesson takes in no audio, even if the mic keeps sending', () async {
    final source = _FakeSource();
    final c = container(source);
    final controller = c.read(recordingControllerProvider.notifier);

    await controller.start();
    expect(c.read(recordingControllerProvider).isRecording, isTrue);

    source.emit(_loud(2000));
    await settle();
    await controller.pause();
    expect(c.read(recordingControllerProvider).isPaused, isTrue);
    final pausesBefore = source.pauses;

    // Native code resumed the engine by itself; the controller must not care.
    source.emit(_loud(3000));
    await settle();
    expect(source.pauses, greaterThan(pausesBefore));

    await controller.resume();
    source.emit(_loud(1000));
    await settle();
    await stopAndDrain(controller);

    expect(c.read(recordingControllerProvider).totalBytes, 3000 * _bytesPerMs);
  });

  test('audio that arrives while the lesson is being set up is kept', () async {
    final source = _FakeSource(earlyBytes: _loud(1500));
    final c = container(source);
    final controller = c.read(recordingControllerProvider.notifier);

    await controller.start();
    source.emit(_loud(500));
    await settle();
    await stopAndDrain(controller);

    expect(c.read(recordingControllerProvider).totalBytes, 2000 * _bytesPerMs);
  });

  test('stop closes the lesson even when the microphone throws', () async {
    final source = _FakeSource(throwOnStop: true);
    final c = container(source);
    final controller = c.read(recordingControllerProvider.notifier);

    await controller.start();
    final id = c.read(recordingControllerProvider).meetingId!;
    source.emit(_loud(1000));
    await settle();
    await stopAndDrain(controller);

    final state = c.read(recordingControllerProvider);
    expect(state.isRecording, isFalse);
    expect(state.error, isNull);
    final meeting = await db.meetingsDao.watchMeetingByIdOnce(id);
    expect(meeting!.endedAt, isNotNull);
  });

  test('a nearly full phone refuses to start and says why', () async {
    final source = _FakeSource();
    final c = container(source, freeBytes: 5 * 1024 * 1024);
    final controller = c.read(recordingControllerProvider.notifier);

    await controller.start();

    final state = c.read(recordingControllerProvider);
    expect(state.isRecording, isFalse);
    expect(state.error, contains('místa'));
    // The lesson row that was opened for it is closed again, not left dangling.
    final open = await (db.select(db.meetings)
          ..where((t) => t.endedAt.isNull()))
        .get();
    expect(open, isEmpty);
  });

  test('low but usable disk starts with a warning', () async {
    final source = _FakeSource();
    final c = container(source, freeBytes: 200 * 1024 * 1024);
    final controller = c.read(recordingControllerProvider.notifier);

    await controller.start();
    expect(c.read(recordingControllerProvider).isRecording, isTrue);
    expect(c.read(recordingControllerProvider).lowDisk, isTrue);
    await stopAndDrain(controller);
    expect(c.read(recordingControllerProvider).lowDisk, isFalse);
  });

  test('a mic that goes quiet is reopened into the same lesson', () async {
    final source = _FakeSource();
    final c = container(source);
    final controller = c.read(recordingControllerProvider.notifier);

    await controller.start();
    source.emit(_loud(500));
    // Real time: the watchdog counts wall-clock seconds without bytes.
    await Future<void>.delayed(const Duration(milliseconds: 4600));
    expect(source.restarts, greaterThanOrEqualTo(1));
    expect(c.read(recordingControllerProvider).isRecording, isTrue);

    // Audio on the new stream keeps landing in the same recording.
    source.emit(_loud(1000));
    await settle();
    await stopAndDrain(controller);
    expect(c.read(recordingControllerProvider).totalBytes, 1500 * _bytesPerMs);
  });
}
