import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/recording_controller.dart';

void main() {
  group('RecordingState elapsedAt', () {
    final started = DateTime(2026, 9, 21, 9);

    test('counts active recording time', () {
      final state = RecordingState(startedAt: started);

      expect(
        state.elapsedAt(started.add(const Duration(minutes: 12))),
        const Duration(minutes: 12),
      );
    });

    test('excludes a completed pause', () {
      final state = RecordingState(
        startedAt: started,
        pausedDuration: const Duration(minutes: 3),
      );

      expect(
        state.elapsedAt(started.add(const Duration(minutes: 12))),
        const Duration(minutes: 9),
      );
    });

    test('excludes the pause currently in progress', () {
      final state = RecordingState(
        startedAt: started,
        isPaused: true,
        pausedAt: started.add(const Duration(minutes: 5)),
        pausedDuration: const Duration(minutes: 2),
      );

      expect(
        state.elapsedAt(started.add(const Duration(minutes: 12))),
        const Duration(minutes: 5),
      );
    });

    test('never returns a negative duration for inconsistent stored state', () {
      final state = RecordingState(
        startedAt: started,
        pausedDuration: const Duration(minutes: 20),
      );

      expect(
        state.elapsedAt(started.add(const Duration(minutes: 5))),
        Duration.zero,
      );
    });
  });
}
