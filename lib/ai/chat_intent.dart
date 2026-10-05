import '../data/db/tables/chat_messages_table.dart';
import '../stt/transcript_sanitizer.dart';
import 'question_detector.dart';

/// Guesses what a message typed into the lesson chat is for, without a request.
///
/// A wrong guess costs one tap — the chip under the bubble cycles it — so this
/// only has to be right most of the time, and free.
///
/// While the lesson [recording] runs, plain text is context for the answers to
/// come („čteme úryvek z Babičky"). Once it is over there is nothing left to
/// give context to, and the bar's hint says „Zeptej se na přepis", so text
/// that is not an obvious rule or a thanks is a question. An explicit
/// „kontext:" / „poznámka:" opener always wins, either way.
ChatIntent detectChatIntent(String text, {bool recording = true}) {
  var words = normalizeForArtifactMatch(text).split(' ')
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return ChatIntent.context;
  while (words.length > 1 && _kPoliteness.contains(words.first)) {
    words = words.sublist(1);
  }

  if (_kContextOpeners.contains(words.first)) return ChatIntent.context;
  if (_kRuleOpeners.contains(words.first)) return ChatIntent.rule;
  if (text.trim().endsWith('?') || looksLikeQuestion(text)) {
    return ChatIntent.question;
  }
  if (_kRequestVerbs.contains(words.first)) return ChatIntent.question;
  if (!recording && !_isAcknowledgement(words)) return ChatIntent.question;
  return ChatIntent.context;
}

bool _isAcknowledgement(List<String> words) =>
    words.length <= 2 && words.every(_kAcknowledgements.contains);

/// The next intent when the student taps the chip.
ChatIntent cycleChatIntent(ChatIntent intent) => switch (intent) {
  ChatIntent.context => ChatIntent.question,
  ChatIntent.question => ChatIntent.rule,
  ChatIntent.rule => ChatIntent.context,
  _ => intent,
};

/// Openers the student types to say „this is background, not a question".
const _kContextOpeners = {'kontext', 'poznamka', 'info', 'informace', 'note'};

/// Imperatives that ask for something to be produced. Matched only as the first
/// word, so „shrň", „vysvětli" and „odpověz mi" are questions while a sentence
/// that merely contains the verb is not.
const _kRequestVerbs = {
  'vysvetli',
  'vysvetlete',
  'shrn',
  'shrnte',
  'shrnout',
  'popis',
  'popiste',
  'definuj',
  'porovnej',
  'uved',
  'uvedte',
  'vyjmenuj',
  'rekni',
  'reknete',
  'napis',
  'vypis',
  'najdi',
  'spocitej',
  'prelozit',
  'preloz',
  'odpovez',
  'odpovezte',
  'zjisti',
  'doporuc',
  'navrhni',
  'pripomen',
  'poradte',
  'pomoz',
  'explain',
  'summarize',
  'summarise',
  'describe',
  'define',
  'compare',
  'tell',
};

/// Replies that are not worth an answer even once the lesson is over.
const _kAcknowledgements = {
  'dik',
  'diky',
  'dekuji',
  'ok',
  'okej',
  'super',
  'jasne',
  'aha',
  'jo',
  'ano',
  'ne',
  'fajn',
  'thanks',
  'thx',
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
