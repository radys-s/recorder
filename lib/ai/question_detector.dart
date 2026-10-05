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
  text = _withoutStutter(text);

  final sentences = [
    // `…` too: Whisper writes a trailing-off sentence with the single
    // character, and without it two sentences read as one whose opener is
    // the first one's.
    for (final s in text.split(RegExp(r'[.!?…\n]+')))
      if (normalizeForArtifactMatch(s).isNotEmpty) s,
  ];

  for (final sentence in sentences) {
    // A sentence with a condition in front is a plan, not a question that
    // happens to open with `jestli`. What follows the condition is left to the
    // pause rule: re-reading it here as a fresh sentence start would turn
    // "Pokud nevíte, kdo to má na starosti, zeptejte se Petra." into a hit.
    if (_mainClauseAfterCondition(sentence) != null) continue;
    if (_opensWithInterrogative(normalizeForArtifactMatch(sentence))) {
      return true;
    }
  }

  if (_kIndirectQuestion.hasMatch(normalizeForArtifactMatch(text))) {
    return true;
  }

  if (endedOnPause && sentences.isNotEmpty) {
    final last = sentences.last;
    for (final clause in _clauses(_mainClauseAfterCondition(last) ?? last)) {
      if (_opensWithInterrogative(clause)) return true;
      if (_kYesNoOpener.hasMatch(
        _withoutLeadingParticles(clause.split(' ')).join(' '),
      )) {
        return true;
      }
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

/// "Na na co se používá" — a recogniser writes a stutter down, and the repeated
/// preposition hides the interrogative behind it from [_opensWithInterrogative].
/// Consecutive identical words (any case, diacritics folded) become one.
String _withoutStutter(String text) => text
    .split('\n')
    .map((line) {
      final out = <String>[];
      String? previous;
      for (final word in line.split(RegExp(r'[ \t]+'))) {
        final folded = normalizeForArtifactMatch(word);
        if (folded.isNotEmpty && folded == previous) continue;
        out.add(word);
        if (folded.isNotEmpty) previous = folded;
      }
      return out.join(' ');
    })
    .join('\n');

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
List<String> _clauses(String sentence) {
  final parts = <String>[];
  for (final part in sentence.split(RegExp(r'[,;:]|\s[-–—]\s'))) {
    final normalized = normalizeForArtifactMatch(part);
    if (normalized.isEmpty) continue;

    // Czech always sets a comma before `že`, and a `že` clause belongs to the
    // one in front of it. Split apart, "Víte, že to nefunguje." left a bare
    // "víte" behind, which reads as a question on its own.
    if (parts.isNotEmpty &&
        (normalized == 'ze' || normalized.startsWith('ze '))) {
      parts[parts.length - 1] = '${parts.last} $normalized';
    } else {
      parts.add(normalized);
    }
  }

  return [
    for (final part in parts)
      for (final clause in part.split(
        RegExp(r'\b(?:a|ale|nebo|takze|tak|and|but|or|so)\b'),
      ))
        if (clause.trim().isNotEmpty) clause.trim(),
  ];
}

bool _opensWithInterrogative(String normalized) {
  if (normalized.isEmpty) return false;

  var words = _withoutLeadingParticles(normalized.split(' '));
  final second = words.length > 1 ? words[1] : '';

  // English `do` is only ever an auxiliary with a subject behind it. On its own
  // it is the Czech preposition — "Do pátku to pošlu." — which opens ordinary
  // statements all day long.
  if (words.first == 'do' && _kDoSubjects.contains(second)) return true;

  // "Na kdy to plánujeme", "Za kolik", "S kým", "O čem": Czech puts the
  // preposition in front of the interrogative, and the question starts one
  // word later than the first rule looks.
  if (_kPrepositions.contains(words.first) &&
      (_kInterrogatives.contains(second) ||
          _kInterrogativeCases.contains(second))) {
    words = words.sublist(1);
  } else if (!_kInterrogatives.contains(words.first)) {
    return false;
  }

  return !_kNotAQuestion.hasMatch(words.join(' '));
}

/// Spoken Czech opens a question with a filler far more often than written
/// Czech does — "A kolik to bude stát", "No a kdy začneme", "Takže kdo to
/// podepíše" — and Whisper keeps the filler while dropping the question mark.
/// Without this, rule 2 saw "a" as the sentence's first word and let exactly
/// the flat-intonation question the user reported go by. Up to two are
/// skipped, and never the last word.
List<String> _withoutLeadingParticles(List<String> words) {
  var skip = 0;
  while (skip < 3 &&
      skip < words.length - 1 &&
      _kLeadingParticles.contains(words[skip])) {
    skip++;
  }
  return skip == 0 ? words : words.sublist(skip);
}

const Set<String> _kLeadingParticles = {
  'a', 'no', 'tak', 'takze', 'ale', 'jo', 'hele', 'teda', 'tedy',
  // The hesitations and softeners speech puts in front of a question.
  'ehm', 'eh', 'em', 'hm', 'hmm', 'jako', 'proste', 'vlastne', 'dobre', 'ok',
  'okej', 'hej', 'nojo',
  'and', 'so', 'but', 'well', 'um', 'uh', 'like', 'okay',
};

/// "Jestli to nestihneme, posuneme termín." opens with `jestli`, but it means
/// "if" there, not "whether" — the sentence is a plan, and its question-shaped
/// opener is only the condition. Returns what follows the condition, or null
/// when the sentence does not open with one.
///
/// Also null when what follows is somebody saying they do not know: "Jestli to
/// stihneme do pátku, to nevím." is exactly the indirect question the user
/// asked for, and must be judged whole.
String? _mainClauseAfterCondition(String sentence) {
  var comma = sentence.indexOf(',');
  if (comma < 0) return null;

  final head = normalizeForArtifactMatch(sentence.substring(0, comma));
  if (!_kConditionOpener.hasMatch(head)) return null;

  // "Pokud nevíte, kdo to má na starosti, zeptejte se Petra." — the clause
  // right after a condition that ends on not knowing is still part of that
  // condition: it is *what* is not known. Cutting at the first comma handed
  // "kdo to má na starosti" to the pause rule as the main clause, and an
  // instruction came out as a question.
  if (_kKnowingAtEnd.hasMatch(head)) {
    final next = sentence.indexOf(',', comma + 1);
    if (next >= 0) comma = next;
  }

  final tail = normalizeForArtifactMatch(sentence.substring(comma + 1));
  if (_kUnknownTail.hasMatch(tail)) return null;

  return sentence.substring(comma + 1);
}

/// Leading fillers allowed too — otherwise "Ale jestli to nestihneme, posuneme
/// termín." skipped this check and [_withoutLeadingParticles] then read the
/// `jestli` as a sentence-initial "whether".
final RegExp _kConditionOpener = RegExp(
  r'^(?:(?:a|no|tak|takze|ale|jo|hele|teda|tedy) ){0,2}'
  r'(?:jestli|jestlize|pokud|kdyz)\b',
);

final RegExp _kKnowingAtEnd = RegExp(
  r'\b(?:ne)?(?:vim|vime|vis|vite|vi|tusim|tusime|tusis|tusite|tusi)$|'
  r'\b(?:jist|jasn|zjist)\w*$',
);

final RegExp _kUnknownTail = RegExp(
  r'^(?:to )?(?:(?:ale|jeste|zatim|fakt|opravdu|presne|uplne) )?'
  r'(?:nevim|nevime|netusim|netusime|nikdo nevi|nevi se|neni jasne|'
  r'je otazka|uvidime|se uvidi|nejsem si jist|nejsme si jisti)',
);

/// Openers that begin with an interrogative word and are still not questions.
/// Matched against the folded sentence after any leading preposition.
final RegExp _kNotAQuestion = RegExp(
  r'^(?:'
  // `co nejdřív`, `jak nejrychleji` — "as soon/fast as possible", common
  // enough in a work meeting that leaving it in would send a steady trickle
  // of statements to the model. Only after `co` and `jak`: "Kdo nejvíc
  // utratil" is a real question.
  r'(?:co|jak) nej|'
  // "Co se týče rozpočtu, …" — "as for".
  r'co se (?:tyce|tyka)\b|'
  // "Jak víte, …", "Jak jsem říkal, …", "Jak už bylo řečeno, …" — a reminder,
  // not a question. "Jak jste to myslel" keeps its `to` and stays a question.
  r'jak (?:vite|vis|vime|je znamo|znamo|rikam|rikate)\b|'
  r'jak (?:(?:uz|jiz|jsem|jste|jsme|jsi|bylo|se|si|vam|ti|nam|jim|drive|predtim) ){1,3}'
  r'(?:rik|rek|zmin|psal|napsal|uved|slib|domluv|dohod|mluvil|ukaz|vysvetl|recen)|'
  // "Mohl jsem to udělat líp." — only the conditional is a request.
  r'mohl[aio]?(?: (?!(?:by|bys|byste|bychom)\b)|$)|'
  // "Víte, že …" — "you know, …".
  r'vi(?:s|te) ze\b|'
  // "Zdá se, že to funguje." folds to `zda se`, the most common false
  // positive of all. Only with the `že` behind it: "Zda se nám to vyplatí."
  // is the rhetorical question M19b was built to catch.
  r'zda (?:se|si)(?: (?:mi|ti|nam|vam|jim|mu|ji))? ze\b'
  r')',
);

/// Subjects that make a sentence-initial `do` an English auxiliary.
const Set<String> _kDoSubjects = {
  'you',
  'we',
  'they',
  'i',
  'anyone',
  'anybody',
  'people',
  'your',
  'our',
};

/// Folded Czech prepositions that can stand in front of an interrogative.
const Set<String> _kPrepositions = {
  'na',
  'za',
  'o',
  's',
  'se',
  'k',
  'ke',
  'v',
  've',
  'z',
  'ze',
  'do',
  'od',
  'pro',
  'po',
  'pred',
  'pres',
  'u',
  'bez',
  'kvuli',
  'mezi',
  'nad',
  'pod',
  'proti',
  'podle',
  'behem',
};

/// Case forms of the interrogatives that only occur after a preposition —
/// "o kom", "v čem", "na kterém" — and would be noise at a sentence start.
const Set<String> _kInterrogativeCases = {
  'kom',
  'cem',
  'kolika',
  'jakem',
  'jakych',
  'jakemu',
  'kterem',
  'kterych',
  'ktereho',
  'kteremu',
  'kterym',
};

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
  'kolik', 'kolikaty', 'kolikata', 'kolikate', 'kolikateho',
  'ktery', 'ktera', 'ktere', 'kterou', 'kteri',
  'zda', 'jestli',
  'muzes', 'muzete', 'dokazes', 'dokazete', 'mohl', 'mohla', 'mohli',
  'vis', 'vite', 'nevis', 'nevite',
  'umis', 'umite', 'znas', 'znate',
  'chces', 'chcete',
  // English — still reachable, since the transcript language is a setting.
  // `do` is handled on its own in [_opensWithInterrogative]: bare, it is the
  // Czech preposition.
  'who', 'whom', 'whose', 'what', 'where', 'when', 'why', 'how', 'which',
  'can', 'could', 'would', 'should', 'shall', 'may', 'might',
  'does', 'did', 'is', 'are', 'was', 'were', 'will', 'has', 'have', 'am',
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
  r'(?:to )?je (?:ta |velka |otevrena )?otazka|'
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
