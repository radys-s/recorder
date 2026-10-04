import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/recording_controller.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/features/meetings_list/widgets/dashboard_stage.dart';
import 'package:recorder/features/subjects/subjects_providers.dart';

class _Recording extends RecordingController {
  _Recording(this.active, {this.paused = false, this.saving = false});
  final bool active;
  final bool paused;
  final bool saving;
  @override
  RecordingState build() => RecordingState(
    isRecording: active,
    isPaused: paused,
    isSaving: saving,
    pausedAt: paused ? DateTime.now() : null,
    startedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 34)),
  );
}

void main() {
  for (final state in [
    (false, false, false),
    (true, false, false),
    (true, true, false),
    (true, false, true),
  ]) {
    final (active, paused, saving) = state;
    testWidgets(
      'dashboard fits narrow large-text active=$active paused=$paused saving=$saving state',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subjectsProvider.overrideWith((ref) => Stream.value(const [])),
              allSlotsProvider.overrideWith((ref) => Stream.value(const [])),
              transcriptionWaitProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
              recordingControllerProvider.overrideWith(
                () => _Recording(active, paused: paused, saving: saving),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DashboardStage(
                    date: 'neděle 4. října',
                    liveSubjectName: 'Velmi dlouhý název vyučovacího předmětu',
                    onStart: () {},
                    onOpen: () {},
                    onResume: () {},
                    onSearch: () {},
                    onSettings: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            saving
                ? 'Ukládám poslední úsek…'
                : paused
                ? 'Pokračovat'
                : active
                ? 'Ukončit'
                : 'Nahrát hodinu',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
