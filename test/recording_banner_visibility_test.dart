import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/recording_controller.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/features/meeting_detail/widgets/recording_indicator_banner.dart';

class _ActiveRecordingController extends RecordingController {
  @override
  RecordingState build() => RecordingState(
    isRecording: true,
    meetingId: 1,
    startedAt: DateTime.now(),
    weakSignal: true,
  );
}

void main() {
  testWidgets('recording strip takes over when the dashboard scrolls away', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingControllerProvider.overrideWith(
            _ActiveRecordingController.new,
          ),
          dashboardStageVisibleProvider.overrideWith((ref) => true),
          dashboardStageInViewProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          builder: (context, child) => RecordingIndicatorBanner(child: child!),
          home: const Scaffold(body: Text('Dashboard')),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.text('Dashboard')),
    );
    expect(find.textContaining('Nahrává se'), findsNothing);

    container.read(dashboardStageInViewProvider.notifier).state = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.textContaining('Nahrává se'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('Nahrává se')).dy,
      lessThan(tester.getTopLeft(find.text('Dashboard')).dy),
    );
    expect(find.bySemanticsLabel(RegExp('Ukončit nahrávání')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Skrýt upozornění')), findsOneWidget);

    container.read(dashboardStageInViewProvider.notifier).state = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Nahrává se'), findsNothing);
    semantics.dispose();
  });
}
