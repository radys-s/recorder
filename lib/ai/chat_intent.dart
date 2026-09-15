import '../data/db/tables/chat_messages_table.dart';
import '../stt/transcript_sanitizer.dart';
import 'question_detector.dart';

/// Guesses what a message typed during a lesson is for, without a request.
///
/// A wrong guess costs one tap — the chip under the bubble cycles it — so this
/// only has to be right most of the time, and free.
ChatIntent detectChatIntent(String text) {
  var words = normalizeForArtifactMatch(text).split(' ')
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return ChatIntent.context;
  while (words.length > 1 && _kPoliteness.contains(words.first)) {
    words = words.sublist(1);
  }

  if (_kRuleOpeners.contains(words.first)) return ChatIntent.rule;
  if (text.trim().endsWith('?') || looksLikeQuestion(text)) {
    return ChatIntent.question;
  }
  return ChatIntent.context;
}

/// The next intent when the student taps the chip.
ChatIntent cycleChatIntent(ChatIntent intent) => switch (intent) {
      ChatIntent.context => ChatIntent.question,
      ChatIntent.question => ChatIntent.rule,
      ChatIntent.rule => ChatIntent.context,
      _ => intent,
    };

const _kPoliteness = {'prosim', 'hele', 'a', 'jo', 'ok', 'okej', 'please'};

/// Imperatives about *how* to answer. „Odpověz" alone is left out on purpose:
/// „odpověz mi, kdo byl Proško" is a question.
const _kRuleOpeners = {
  'pravidlo',
  'odpovidej',
  'neodpovidej',
  'odpovedi',
  'pis',
  'nepis',
  'vysvetluj',
  'nevysvetluj',
  'pouzivej',
  'nepouzivej',
  'mluv',
  'bud',
  'davej',
  'nedavej',
  'uvadej',
  'neuvadej',
  'vzdy',
  'nikdy',
  'pokazde',
  'strucne',
  'rule',
  'always',
  'never',
};
