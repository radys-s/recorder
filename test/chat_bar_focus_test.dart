import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/chat_answer_service.dart';
import 'package:recorder/audio/recording_controller.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';
import 'package:recorder/features/meeting_detail/widgets/chat_bar.dart';

/// Questions reach the service after a lesson; the real one would start a
/// 70 s watchdog timer that the test binding sees as a leak.
class _FakeAnswers implements ChatAnswerService {
  final asked = <int>[];

  @override
  Future<void> ask(int userMessageId) async => asked.add(userMessageId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Idle extends RecordingController {
  @override
  RecordingState build() => const RecordingState();
}

class _Live extends RecordingController {
  @override
  RecordingState build() => RecordingState(
    isRecording: true,
    meetingId: 1,
    startedAt: DateTime.now(),
  );
}

Future<AppDatabase> _pump(
  WidgetTester tester, {
  required bool recording,
  VoidCallback? onSent,
  double scale = 1,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        chatAnswerServiceProvider.overrideWithValue(_FakeAnswers()),
        recordingControllerProvider.overrideWith(
          recording ? _Live.new : _Idle.new,
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: scale > 1,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Expanded(child: Center(child: Text('přepis'))),
                ChatBar(
                  meetingId: 1,
                  recording: recording,
                  onSent: onSent,
                  keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return db;
}

/// drift cancels stream queries on a zero timer, and the framework checks
/// pending timers before tearDown — unmount inside the test body.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
}

bool _focused(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

void main() {
  for (final recording in [false, true]) {
    testWidgets(
      'chat controls fit 320px, large text and keyboard, recording=$recording',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await _pump(tester, recording: recording, scale: 2);
        await tester.tap(find.byType(TextField));
        await tester.enterText(
          find.byType(TextField),
          'Velmi dlouhá otázka k této uložené hodině?',
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Odeslat'), findsOneWidget);
        await _unmount(tester);
      },
    );
  }
  testWidgets('tapping outside the bar puts the keyboard away', (tester) async {
    await _pump(tester, recording: false);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(_focused(tester), isTrue);
    expect(find.text('Skrýt klávesnici'), findsOneWidget);

    await tester.tap(find.text('přepis'));
    await tester.pumpAndSettle();
    expect(_focused(tester), isFalse);
    expect(find.text('Skrýt klávesnici'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('the hide-keyboard button closes it', (tester) async {
    await _pump(tester, recording: true);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Skrýt klávesnici'));
    await tester.pumpAndSettle();
    expect(_focused(tester), isFalse);
    await _unmount(tester);
  });

  testWidgets('a tap on a button inside the bar keeps the field focused', (
    tester,
  ) async {
    final db = await _pump(tester, recording: true);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Důležité'));
    await tester.pump();
    expect(_focused(tester), isTrue);
    await tester.runAsync(() => db.chatMessagesDao.messages(1));
    await tester.pump(const Duration(seconds: 3));
    await _unmount(tester);
  });

  testWidgets('Escape closes the keyboard', (tester) async {
    await _pump(tester, recording: false);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_focused(tester), isFalse);
    await _unmount(tester);
  });

  testWidgets('sending after the lesson closes the keyboard and reports it', (
    tester,
  ) async {
    var sent = 0;
    final db = await _pump(tester, recording: false, onSent: () => sent++);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Čteme Babičku.');
    await tester.pump();
    await tester.tap(find.byTooltip('Odeslat'));
    await tester.pump();
    await tester.runAsync(() => db.chatMessagesDao.messages(1));
    await tester.pump(const Duration(seconds: 1));
    expect(_focused(tester), isFalse);
    expect(sent, 1);
    expect(find.text('Čteme Babičku.'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('sending while recording keeps the field for the next note', (
    tester,
  ) async {
    final db = await _pump(tester, recording: true);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Čteme Babičku.');
    await tester.pump();
    await tester.tap(find.byTooltip('Odeslat'));
    await tester.pump();
    await tester.runAsync(() => db.chatMessagesDao.messages(1));
    await tester.pump(const Duration(seconds: 1));
    expect(_focused(tester), isTrue);
    await _unmount(tester);
  });

  group('„Odešle se jako" label', () {
    testWidgets('follows what is typed and the lesson state', (tester) async {
      await _pump(tester, recording: true);
      expect(find.textContaining('Odešle se jako'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Čteme Babičku.');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Kontext'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Kdo byl Proško?');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Otázka'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('after the lesson plain text is a question', (tester) async {
      await _pump(tester, recording: false);
      await tester.enterText(find.byType(TextField), 'Čteme Babičku.');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Otázka'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a tap cycles it and the choice is what gets stored', (
      tester,
    ) async {
      final db = await _pump(tester, recording: true);
      await tester.enterText(find.byType(TextField), 'Čteme Babičku.');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Kontext'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Otázka'), findsOneWidget);
      await tester.tap(find.text('Otázka'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Pravidlo'), findsOneWidget);

      await tester.tap(find.byTooltip('Odeslat'));
      await tester.pump();
      final stored = await tester.runAsync(
        () => db.chatMessagesDao.messages(1),
      );
      expect(stored!.single.intent, ChatIntent.rule);
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Odešle se jako'), findsNothing);
      await _unmount(tester);
    });
  });
}
