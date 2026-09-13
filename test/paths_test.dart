import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/paths.dart';

void main() {
  group('toStoredPath', () {
    test('strips the documents directory', () {
      expect(
        toStoredPath(
          '/data/user/0/com.example/app_flutter',
          '/data/user/0/com.example/app_flutter/recordings/meeting_12/'
              'chunk_0003.wav',
        ),
        'recordings/meeting_12/chunk_0003.wav',
      );
    });

    test('leaves a path outside the documents directory alone', () {
      expect(
        toStoredPath('/data/user/0/com.example/app_flutter', '/sdcard/x.wav'),
        '/sdcard/x.wav',
      );
    });

    test('a trailing separator on the base changes nothing', () {
      expect(
        toStoredPath('/docs/', '/docs/recordings/meeting_1/chunk_0000.wav'),
        'recordings/meeting_1/chunk_0000.wav',
      );
    });
  });

  group('resolveStoredPath', () {
    // The relative branch needs a documents directory and therefore a
    // platform channel, so it is covered on device rather than here. What is
    // testable off-device is the branch that must keep working for every row
    // written before this existed.
    test('an absolute stored path comes back untouched', () async {
      const stored = '/data/user/0/com.example/app_flutter/recordings/a.wav';
      expect(await resolveStoredPath(stored), stored);
    });
  });
}
