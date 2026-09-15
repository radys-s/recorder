import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/chat_answer_service.dart';
import 'package:recorder/ai/context_builder.dart';
import 'package:recorder/ai/lesson_context_source.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/chat_messages_table.dart';

class _FakeLlm extends LlmProvider {
  _FakeLlm(this.reply);

  final Object reply;
  final models = <String>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    models.add(model);
    final r = reply;
    if (r is Exception) throw r;
    return LlmCompletion(content: r as String);
  }
}

class _NoMaterial implements LessonContextSource {
  @override
  Future<LessonMaterial> load(int meetingId) async => const LessonMaterial();

  @override
  Future<void> markUsed(int cardId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _answer = '{"short": "Myslivec", "detail": "", "basis": "knowledge"}';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ChatMessage?> ask(ChatAnswerService service) async {
    final q = await db.chatMessagesDao.addUserMessage(
        meetingId: 1,
        text: 'Kdo byl Proško?',
        intent: ChatIntent.question,
        atMs: 0);
    await service.ask(q);
    return db.chatMessagesDao.replyTo(q);
  }

  ChatAnswerService service(_FakeLlm groq, _FakeLlm gemini, bool hasKey) =>
      ChatAnswerService(
        groq,
        db.chatMessagesDao,
        db.transcriptSegmentsDao,
        _NoMaterial(),
        gemini: gemini,
        hasGeminiKey: () async => hasKey,
      );

  test('with a Gemini key the question goes to Gemini only', () async {
    final groq = _FakeLlm(_answer);
    final gemini = _FakeLlm(_answer);
    final reply = await ask(service(groq, gemini, true));

    expect(gemini.models, [kGeminiModel]);
    expect(groq.models, isEmpty);
    expect(reply!.status, ChatStatus.ready);
    expect(reply.short, 'Myslivec');
  });

  test('without a key Groq answers and Gemini is never called', () async {
    final groq = _FakeLlm(_answer);
    final gemini = _FakeLlm(_answer);
    await ask(service(groq, gemini, false));

    expect(gemini.models, isEmpty);
    expect(groq.models, [kGroqAnswerModel]);
  });

  test('a Gemini failure falls back to Groq and still answers', () async {
    final groq = _FakeLlm(_answer);
    final gemini = _FakeLlm(const AiTransientException('429'));
    final reply = await ask(service(groq, gemini, true));

    expect(gemini.models, hasLength(1));
    expect(groq.models, [kGroqAnswerModel]);
    expect(reply!.status, ChatStatus.ready);
  });

  test('the Gemini budget is far larger than the Groq one', () {
    expect(ContextBudget.gemini.total,
        greaterThan(ContextBudget.direct.total * 3));
  });
}
