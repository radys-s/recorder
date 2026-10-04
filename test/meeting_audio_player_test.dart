import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/recording_controller.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/features/meeting_detail/widgets/meeting_audio_player.dart';

class _Recording extends RecordingController {
  _Recording(this.active);
  final bool active;
  @override
  RecordingState build() => RecordingState(isRecording: active);
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool active = false,
    bool cleared = false,
    List<TranscriptSegment> segments = const [],
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        recordingControllerProvider.overrideWith(() => _Recording(active)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MeetingAudioPlayer(segments: segments, audioCleared: cleared),
        ),
      ),
    ),
  );
  final missing = TranscriptSegment(
    id: 1,
    meetingId: 1,
    sequence: 0,
    startMs: 0,
    endMs: 1000,
    status: SegmentStatus.transcribed,
    localAudioPath:
        '${Directory.systemTemp.path}/aftermind_intentionally_missing/chunk.wav',
    createdAt: DateTime(2026),
  );

  testWidgets(
    'empty and retained-text-only lessons explain unavailable audio',
    (tester) async {
      await pump(tester);
      expect(
        find.text('Zvuk se objeví po uložení prvního úseku.'),
        findsOneWidget,
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      await pump(tester, cleared: true, segments: [missing]);
      expect(find.textContaining('Zvuk byl uvolněn'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'capture disables playback instead of competing for the audio session',
    (tester) async {
      await pump(tester, active: true, segments: [missing]);
      expect(find.textContaining('po ukončení nahrávání'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'a missing local file gives a recoverable message, not an endless loader',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, segments: [missing]);
      await tester.runAsync(() async {
        await tester.tap(find.byType(IconButton));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Část uloženého zvuku chybí'), findsOneWidget);
      expect(find.text('Zkusit znovu'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await pump(tester, cleared: true, segments: [missing]);
      expect(find.textContaining('Zvuk byl uvolněn'), findsOneWidget);
      expect(find.text('Zkusit znovu'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
