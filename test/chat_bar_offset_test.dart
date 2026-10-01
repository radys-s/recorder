import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/audio/recording_controller.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/meeting_detail/widgets/chat_bar.dart';

/// 20 minutes of wall clock, 15 of them paused: the audio is 5 minutes long.
class _PausedEarlierController extends RecordingController {
  @override
  RecordingState build() => RecordingState(
    isRecording: true,
    meetingId: 1,
    startedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    pausedDuration: const Duration(minutes: 15),
  );
}

void main() {
  testWidgets('⭐ is placed in audio time, not in wall-clock time', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          recordingControllerProvider.overrideWith(
            _PausedEarlierController.new,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatBar(meetingId: 1, recording: true)),
        ),
      ),
    );

    await tester.tap(find.text('Důležité'));
    await tester.pump();
    final messages = (await tester.runAsync(
      () => db.chatMessagesDao.messages(1),
    ))!;
    await tester.pump(const Duration(seconds: 3));

    expect(messages, hasLength(1));
    // 5 minutes of audio, give or take the time the test itself took.
    expect(
      messages.single.atMs,
      inInclusiveRange(5 * 60 * 1000, 5 * 60 * 1000 + 5000),
    );
  });
}
