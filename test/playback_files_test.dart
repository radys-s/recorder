import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/playback_files.dart';
import 'package:recorder/audio/playback_timeline.dart';
import 'package:recorder/audio/local_playback.dart';

void main() {
  late Directory dir;
  setUp(
    () => dir = Directory.systemTemp.createTempSync('aftermind_playback_test'),
  );
  tearDown(() => dir.deleteSync(recursive: true));
  PlaybackClip clip(String name, int start, int end) =>
      PlaybackClip(path: '${dir.path}/$name', startMs: start, endMs: end);
  test(
    'resolves every local chunk, including silence, in audio order',
    () async {
      final a = File('${dir.path}/a.wav');
      final b = File('${dir.path}/b.wav');
      await a.writeAsBytes(List.filled(76, 0));
      await b.writeAsBytes(List.filled(76, 0));
      expect(
        await resolvePlaybackFiles([clip('a.wav', 0, 1), clip('b.wav', 1, 2)]),
        [a.uri, b.uri],
      );
      expect(await a.length(), 76);
    },
  );
  test('fails explicitly rather than skipping a missing chunk', () async {
    await expectLater(
      resolvePlaybackFiles([clip('missing.wav', 0, 1)]),
      throwsA(
        isA<PlaybackUnavailable>().having(
          (e) => e.reason,
          'reason',
          PlaybackUnavailableReason.missingFile,
        ),
      ),
    );
  });
  test('rejects empty files and incomplete timelines', () async {
    await File('${dir.path}/empty.wav').writeAsBytes([]);
    await expectLater(
      resolvePlaybackFiles([clip('empty.wav', 0, 1)]),
      throwsA(
        isA<PlaybackUnavailable>().having(
          (e) => e.reason,
          'reason',
          PlaybackUnavailableReason.emptyFile,
        ),
      ),
    );
    await expectLater(
      resolvePlaybackFiles([clip('empty.wav', 1, 2)]),
      throwsA(
        isA<PlaybackUnavailable>().having(
          (e) => e.reason,
          'reason',
          PlaybackUnavailableReason.incompleteTimeline,
        ),
      ),
    );
  });
  test(
    'capture guard can be activated without allocating a native player',
    () async {
      final playback = LocalPlayback();
      await playback.suspendForCapture();
      expect(playback.captureRequested, isTrue);
      playback.releaseCapture();
      expect(playback.captureRequested, isFalse);
      await playback.dispose();
    },
  );
  test('capture waits for in-flight playlist preparation', () async {
    final playback = LocalPlayback();
    final ready = Completer<void>();
    final preparing = playback.prepare(() => ready.future);
    var captureReady = false;
    final capture = playback.suspendForCapture().then(
      (_) => captureReady = true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(playback.captureRequested, isTrue);
    expect(captureReady, isFalse);
    ready.complete();
    await preparing;
    await capture;
    expect(captureReady, isTrue);
    await playback.dispose();
  });
  test('a failed playlist preparation does not block capture', () async {
    final playback = LocalPlayback();
    final ready = Completer<void>();
    final preparing = playback.prepare(() => ready.future);
    final failure = expectLater(preparing, throwsStateError);
    final capture = playback.suspendForCapture();
    ready.completeError(StateError('synthetic decoder failure'));
    await failure;
    await capture;
    expect(playback.captureRequested, isTrue);
    await playback.dispose();
  });
}
