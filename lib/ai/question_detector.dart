import '../stt/transcript_sanitizer.dart';

/// Cheap pre-filter: could this passage contain a question?
///
/// This is not the decision — [LiveAnswerService] asks the model that. Its job
/// is to keep the overwhelming majority of segments, which are plain
/// statements, from ever reaching the network. It is therefore deliberately
/// permissive: a false positive costs one small LLM call, a false negative
/// costs the user the answer they were waiting for.
///
/// It cannot simply be skipped, though. The answer model shares an 8 000
/// tokens-per-minute ceiling with the web hop, and live mode cuts a chunk
/// every seven or eight seconds — sending all of them would spend the budget
/// on statements and lose the answers to 429s.
///
/// Five rules, in order:
///  1. a `?` anywhere — Whisper punctuates questions reliably, so this alone
///     catches nearly everything;
///  2. a *sentence* opening with an interrogative word, as the backstop for
///     the times it does not;
///  3. an indirect-question phrase anywhere — "nevím, kdy to bude", "zajímalo
///     by mě", "stihneme to, nebo ne" — which is how people actually put a
///     question on the table without ever intoning one, and which Whisper
///     therefore writes with a full stop;
///  4. [endedOnPause] only: an interrogative opening any *clause* of the
///     closing sentence;
///  5. [endedOnPause] only: the closing sentence opening with a polite or
///     modal yes/no opener ("nešlo by", "dá se", "stihneme").
///
/// Rules 1 and 2 split on sentence terminators only, never on commas. `co`,
/// `jak` and `kdy` are all common mid-sentence in ordinary Czech ("ukázal jsem
/// jim, jak se to dělá"), and splitting on commas would send almost every
/// segment to the model — which is exactly what this function exists to
/// prevent.
///
/// Rules 4 and 5 do exactly that comma split, which is why they are gated on
/// the pause: see [endedOnPause].
bool looksLikeQuestion(String text, {bool endedOnPause = false}) {
  if (text.contains('?')) return true;

  final sentences = [
    for (final s in text.split(RegExp(r'[.!?\n]+')))
      if (normalizeForArtifactMatch(s).isNotEmpty) s,
  ];

  for (final sentence in sentences) {
    if (_opensWithInterrogative(normalizeForArtifactMatch(sentence))) {
      return true;
    }
  }

  if (_kIndirectQuestion.hasMatch(normalizeForArtifactMatch(text))) {
    return true;
  }

  if (endedOnPause && sentences.isNotEmpty) {
    for (final clause in _clauses(sentences.last)) {
      if (_opensWithInterrogative(clause)) return true;
      if (_kYesNoOpener.hasMatch(clause)) return true;
    }
  }

  return false;
}

/// True when the chunk carrying [text] was cut by the silence detector, i.e.
/// somebody stopped talking right after this passage.
///
/// This is the "rhetorical question followed by a pause" case the user asked
/// for. A rhetorical question is precisely the one a speaker trails off on —
/// "…a kolik nás to vlastně bude stát." — so it arrives without a question
/// mark and with the interrogative buried mid-sentence, and the first two
/// rules miss it. The chunker's own cut is the evidence that the room went
/// quiet there, so the extra permissiveness is spent only on the last sentence
/// before that silence, and never on the middle of a passage that ran straight
/// on into the next one.
bool chunkEndedOnPause(Duration chunkDuration, Duration maxPauseCutDuration) =>
    chunkDuration < maxPauseCutDuration;

/// The clauses of one sentence, each returned in the folded, lowercase form
/// [_opensWithInterrogative] expects.
///
/// Split first on the punctuation that separates clauses — which has to happen
/// *before* normalising, since normalising strips punctuation — and then on the
/// coordinating conjunctions Czech speakers actually start a trailing question
/// with.
///
/// "A kolik nás to vlastně bude stát" yields "kolik nas to vlastne bude stat",
/// which opens with an interrogative. "Rozpočet je dva miliony" does not split
/// at all and opens with "rozpocet", so it stays out.
Iterable<String> _clauses(String sentence) sync* {
  for (final part in sentence.split(RegExp(r'[,;:]|\s[-–—]\s'))) {
    final normalized = normalizeForArtifactMatch(part);
    if (normalized.isEmpty) continue;

    for (final clause in normalized
        .split(RegExp(r'\b(?:a|ale|nebo|takze|tak|and|but|or|so)\b'))) {
      final trimmed = clause.trim();
      if (trimmed.isNotEmpty) yield trimmed;
    }
  }
}

bool _opensWithInterrogative(String normalized) {
  if (normalized.isEmpty) return false;

  final words = normalized.split(' ');
  if (!_kInterrogatives.contains(words.first)) return false;

  // `co nejdřív`, `co nejrychleji` — "as soon as possible", not a question,
  // and common enough in a work meeting that leaving it in would send a
  // steady trickle of statements to the model.
  if (words.length > 1 && words[1].startsWith('nej')) return false;

  return true;
}

/// Written in the folded, lowercase form [normalizeForArtifactMatch] produces,
/// so a transcript that lost its diacritics still matches.
///
/// `čí` is missing on purpose: it folds to `ci`, which is also `či` ("or"), and
/// the ambiguity is not worth the handful of questions it would catch.
const Set<String> _kInterrogatives = {
  // Czech
  'kdo', 'koho', 'komu', 'kym',
  'co', 'ceho', 'cemu', 'cim',
  'kde', 'kam', 'odkud', 'kudy',
  'kdy', 'dokdy', 'odkdy',
  'proc',
  'jak', 'jaky', 'jaka', 'jake', 'jaci', 'jakou', 'jakeho', 'jakym',
  'kolik',
  'ktery', 'ktera', 'ktere', 'kterou', 'kteri',
  'zda', 'jestli',
  'muzes', 'muzete', 'mohl', 'mohli',
  'vis', 'vite', 'nevis', 'nevite',
  'umis', 'umite', 'znas', 'znate',
  'chces', 'chcete',
  // English — still reachable, since the transcript language is a setting.
  'who', 'whom', 'whose', 'what', 'where', 'when', 'why', 'how', 'which',
  'can', 'could', 'would', 'should', 'shall', 'may', 'might',
  'do', 'does', 'did', 'is', 'are', 'was', 'were', 'will', 'has', 'have', 'am',
};

/// Phrases that put a question on the table without a question's intonation.
///
/// Every one of them is a way of saying "I want to know X" — which is what a
/// question is — and every one of them comes back from Whisper with a full
/// stop, because nobody's voice rose. Matched anywhere in the passage, not
/// only at a sentence start: "Teď k té první věci. Nevím přesně, kolik to
/// dělá." is the typical shape.
///
/// `nevím` needs an interrogative right behind it (one word such as "přesně"
/// may sit between), so "nevím, to je na tobě" stays out.
final RegExp _kIndirectQuestion = RegExp(
  r'\b(?:'
  r'zajimalo by (?:me|nas)|zajima (?:me|nas)|'
  r'otazka (?:je|zni|zustava)|otazkou je|zustava otazka|'
  r'nevim(?:e)? (?:\w+ )?(?:jestli|zda|kolik|jak\w*|kdy|kdo|co|proc|kde|kam|kter\w*)|'
  r'netusi(?:m|me)|nejsem si jist\w*|nejsme si jisti|'
  r'chtel(?:a|i)? (?:bych|bychom) vedet|'
  r'potrebuj\w* (?:vedet|zjistit)|'
  r'rekni(?:te)? mi|reknete mi|vysvetli(?:te)?|poradte|porad mi|'
  r'nebo ne|'
  r'i wonder|do you know|not sure (?:if|whether)|or not|tell me'
  r')\b',
);

/// Yes/no openers that, in a meeting, are a question far more often than a
/// statement. Only consulted for the closing sentence of a passage that ended
/// on a pause.
///
/// Plain `je`, `máme` or `musíme` are deliberately absent: as text, "Musíme to
/// stihnout do pátku." is a statement exactly as often as it is a question —
/// only the intonation Whisper failed to hear could tell — and matching them
/// would spend the token budget on statements.
final RegExp _kYesNoOpener = RegExp(
  r'^(?:neslo by|slo by|nedalo by se|dalo by se|da se|je mozne|bylo by mozne|'
  r'nemohli bychom|nemeli bychom|stihneme|zvladneme|vyplati se)\b',
);
