import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/board_photo_service.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/meeting_detail/widgets/chat_message_tile.dart';

class _FakeBoard implements BoardPhotoService {
  final answered = <int>[];

  @override
  Future<void> answerQuestions(int messageId) async => answered.add(messageId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// drift cancels stream queries on a zero timer, and the framework checks
/// pending timers before tearDown — unmount inside the test body.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  late AppDatabase db;
  late _FakeBoard board;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    board = _FakeBoard();
  });
  tearDown(() => db.close());

  /// A read photo with [text]; [withReply] adds the answer under it.
  Future<ChatMessage> seed(
    WidgetTester tester, {
    required String text,
    bool withReply = false,
  }) async {
    return (await tester.runAsync(() async {
      final meeting = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(
          title: 'Hodina',
          createdAt: DateTime(2026, 10, 5),
        ),
      );
      final id = await db.chatMessagesDao.addPhotoMessage(
        meetingId: meeting,
        // Absolute and missing: the bubble falls back to its placeholder.
        imagePath: '/no/such/photo.jpg',
        atMs: 0,
      );
      await db.chatMessagesDao.completePhoto(
        id,
        text: text,
        description: 'Pracovní list',
      );
      if (withReply) {
        final reply = await db.chatMessagesDao.addPendingReply(
          meetingId: meeting,
          replyTo: id,
          atMs: 0,
        );
        await db.chatMessagesDao.completeReply(
          reply,
          short: 'Proško',
          detail: '1) Proško.',
          basis: 'knowledge',
        );
      }
      return (await db.chatMessagesDao.message(id))!;
    }))!;
  }

  Future<void> pump(WidgetTester tester, ChatMessage message) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          boardPhotoServiceProvider.overrideWithValue(board),
        ],
        child: MaterialApp(
          home: Scaffold(body: ChatMessageTile(message: message)),
        ),
      ),
    );
    // Let the drift streams deliver their first rows.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a read photo with no answer offers to answer its questions', (
    tester,
  ) async {
    final message = await seed(tester, text: '1) Kdo byl Proško?');
    await pump(tester, message);

    expect(find.text('Odpověz na otázky z fotky'), findsOneWidget);
    await tester.tap(find.text('Odpověz na otázky z fotky'));
    await tester.pump();
    expect(board.answered, [message.id]);
    await _unmount(tester);
  });

  testWidgets('no button once the photo has an answer under it', (
    tester,
  ) async {
    final message = await seed(
      tester,
      text: '1) Kdo byl Proško?',
      withReply: true,
    );
    await pump(tester, message);

    expect(find.text('Odpověz na otázky z fotky'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('no button for a photo with no readable text', (tester) async {
    final message = await seed(tester, text: '');
    await pump(tester, message);

    expect(find.text('Odpověz na otázky z fotky'), findsNothing);
    await _unmount(tester);
  });
}
