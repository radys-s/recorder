import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/playback_timeline.dart';

void main() {
  const clips = [
    PlaybackClip(path: 'a.wav', startMs: 0, endMs: 8000),
    PlaybackClip(path: 'b.wav', startMs: 8000, endMs: 13000),
  ];
  test('maps seeking across chunk boundaries and clamps endpoints', () {
    expect(playbackLocation(clips, const Duration(seconds: 8)), (
      index: 1,
      position: Duration.zero,
    ));
    expect(playbackLocation(clips, const Duration(seconds: 10)), (
      index: 1,
      position: const Duration(seconds: 2),
    ));
    expect(playbackLocation(clips, const Duration(seconds: -1)), (
      index: 0,
      position: Duration.zero,
    ));
    expect(playbackLocation(clips, const Duration(hours: 1)), (
      index: 1,
      position: const Duration(seconds: 5),
    ));
  });
  test('does not silently skip timeline gaps or invalid chunks', () {
    expect(isContinuousPlayback(clips), isTrue);
    expect(isContinuousPlayback(const []), isFalse);
    expect(
      isContinuousPlayback(const [
        PlaybackClip(path: 'a', startMs: 3, endMs: 8),
      ]),
      isFalse,
    );
    expect(
      isContinuousPlayback(const [
        PlaybackClip(path: 'a', startMs: 0, endMs: 0),
      ]),
      isFalse,
    );
    expect(
      isContinuousPlayback([
        clips[0],
        PlaybackClip(path: 'b', startMs: 9000, endMs: 10000),
      ]),
      isFalse,
    );
    expect(() => playbackLocation(const [], Duration.zero), throwsStateError);
  });
}
