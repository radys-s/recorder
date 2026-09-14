import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/question_detector.dart';

void main() {
  group('looksLikeQuestion', () {
    test('a question mark anywhere is enough', () {
      expect(looksLikeQuestion('Tak jo. A kolik to bude stát?'), isTrue);
      expect(looksLikeQuestion('Kdy to má být hotové? Ptám se kvůli plánu.'),
          isTrue);
    });

    test('catches a question whose mark Whisper dropped', () {
      expect(looksLikeQuestion('Proč to trvá tak dlouho.'), isTrue);
      expect(looksLikeQuestion('Kolik nám zbývá v rozpočtu.'), isTrue);
    });

    test('works without diacritics', () {
      expect(looksLikeQuestion('Proc to trva tak dlouho.'), isTrue);
      expect(looksLikeQuestion('Ktery dodavatel je levnejsi.'), isTrue);
    });

    test('plain statements do not match', () {
      expect(
        looksLikeQuestion(
          'Z původního rozpočtu dvou milionů jsme vyčerpali zhruba čtyřicet '
          'procent. Většina nákladů šla na licence.',
        ),
        isFalse,
      );
      expect(looksLikeQuestion('Karel připraví přehled výdajů do pátku.'),
          isFalse);
    });

    test('an interrogative in the middle of a statement does not match', () {
      // The reason clauses are split on sentence terminators and never on
      // commas: these are ordinary Czech statements, and matching them would
      // send nearly every segment to the model.
      expect(looksLikeQuestion('Ukázal jsem jim, jak se to dělá.'), isFalse);
      expect(looksLikeQuestion('Pošlu ti, co jsme probrali.'), isFalse);
    });

    test('a second sentence can be the question', () {
      expect(
        looksLikeQuestion('To je jasné. Kdo to má na starosti.'),
        isTrue,
      );
    });

    test('English still matches', () {
      expect(looksLikeQuestion('How long will it take.'), isTrue);
      expect(looksLikeQuestion('The budget is fine for now.'), isFalse);
    });

    test('empty and whitespace-only input is not a question', () {
      expect(looksLikeQuestion(''), isFalse);
      expect(looksLikeQuestion('   \n  '), isFalse);
      expect(looksLikeQuestion('...'), isFalse);
    });
  });

  group('looksLikeQuestion, indirect questions', () {
    // What the user reported: a question put without a question's intonation
    // comes back from Whisper with a full stop, and got no answer.
    test('"nevím" followed by an interrogative', () {
      expect(looksLikeQuestion('Nevím, kdy to bude hotové.'), isTrue);
      expect(
        looksLikeQuestion('Teď k té věci. Nevím přesně, kolik to dělá.'),
        isTrue,
      );
      expect(looksLikeQuestion('Zatím nevíme, jestli to zvládneme.'), isTrue);
    });

    test('"nevím" on its own is not a question', () {
      expect(looksLikeQuestion('Nevím, to je na tobě.'), isFalse);
    });

    test('wanting to know', () {
      expect(looksLikeQuestion('Zajímalo by mě, kdo to schválil.'), isTrue);
      expect(looksLikeQuestion('Potřebuju vědět termín dodání.'), isTrue);
      expect(looksLikeQuestion('Chtěl bych vědět, co to stojí.'), isTrue);
      expect(looksLikeQuestion('Řekni mi, co potřebuješ.'), isTrue);
    });

    test('an open question named as one', () {
      expect(looksLikeQuestion('Otázka je, co na to řekne úřad.'), isTrue);
    });

    test('"nebo ne" turns a statement into a question', () {
      expect(looksLikeQuestion('Stihne se to do pátku, nebo ne.'), isTrue);
    });

    test('English indirect questions', () {
      expect(looksLikeQuestion("I wonder who signed it off."), isTrue);
      expect(looksLikeQuestion("I'm not sure if it ships this week."), isTrue);
    });
  });

  group('looksLikeQuestion, after a pause', () {
    // The chunker cut right after this passage, so somebody stopped talking
    // there. That is the only case in which a mid-sentence interrogative is
    // allowed to count.
    test('a trailing rhetorical question with no question mark matches', () {
      // Mid-sentence, after a comma: a sentence of its own that opens with
      // "A kolik" now matches without the pause (see the filler test below).
      const text = 'Musíme to stihnout do konce roku, '
          'a kolik nás to vlastně bude stát.';
      expect(looksLikeQuestion(text), isFalse);
      expect(looksLikeQuestion(text, endedOnPause: true), isTrue);
    });

    test('an interrogative after a comma matches', () {
      const text = 'Záleží na tom, kdy dorazí dodávka.';
      expect(looksLikeQuestion(text), isFalse);
      expect(looksLikeQuestion(text, endedOnPause: true), isTrue);
    });

    test('a modal yes/no opener matches', () {
      const text = 'Rozpočet je napjatý. Nešlo by to udělat levněji.';
      expect(looksLikeQuestion(text), isFalse);
      expect(looksLikeQuestion(text, endedOnPause: true), isTrue);
      expect(
        looksLikeQuestion('Dobře, a stihneme to do pátku.', endedOnPause: true),
        isTrue,
      );
    });

    test('a plain verb-first statement stays out', () {
      expect(
        looksLikeQuestion('Musíme to stihnout do pátku.', endedOnPause: true),
        isFalse,
      );
    });

    test('only the closing sentence is treated this permissively', () {
      // The pause is evidence about the end of the chunk, not about its
      // middle — otherwise this rule would send nearly every segment to the
      // model, which is what the pre-filter exists to prevent.
      const text = 'Ukázal jsem jim, co potřebují. Objednávku pošleme zítra.';
      expect(looksLikeQuestion(text, endedOnPause: true), isFalse);
    });

    test('a plain closing statement still does not match', () {
      expect(
        looksLikeQuestion(
          'Rozpočet je dva miliony a zatím jsme vyčerpali polovinu.',
          endedOnPause: true,
        ),
        isFalse,
      );
    });

    test('"co nejdřív" is an idiom, not a question', () {
      expect(
        looksLikeQuestion(
          'Potřebujeme to hotové a co nejdřív.',
          endedOnPause: true,
        ),
        isFalse,
      );
    });
  });

  group('looksLikeQuestion, edge cases from review', () {
    test('a filler in front of the interrogative still opens a question', () {
      expect(looksLikeQuestion('A kolik nás to bude stát.'), isTrue);
      expect(looksLikeQuestion('No a kdy začneme.'), isTrue);
      expect(looksLikeQuestion('Takže kdo to podepíše.'), isTrue);
      expect(looksLikeQuestion('No stihneme to do pátku.', endedOnPause: true),
          isTrue);
    });

    test('a filler alone, or in front of a statement, is not a question', () {
      expect(looksLikeQuestion('No jo.'), isFalse);
      expect(looksLikeQuestion('A tak.', endedOnPause: true), isFalse);
      expect(looksLikeQuestion('Tak to je všechno.', endedOnPause: true),
          isFalse);
      expect(looksLikeQuestion('A do pátku to pošlu.', endedOnPause: true),
          isFalse);
    });

    test('a condition with a filler in front is still a condition', () {
      const text = 'Ale jestli to nestihneme, posuneme termín.';
      expect(looksLikeQuestion(text), isFalse);
      expect(looksLikeQuestion(text, endedOnPause: true), isFalse);
    });

    test('what is not known belongs to the condition, not to the main clause',
        () {
      const text = 'Pokud nevíte, kdo to má na starosti, zeptejte se Petra.';
      expect(looksLikeQuestion(text), isFalse);
      expect(looksLikeQuestion(text, endedOnPause: true), isFalse);
      expect(
        looksLikeQuestion(
          'Když není jasné, kdo to platí, napište mi.',
          endedOnPause: true,
        ),
        isFalse,
      );
    });

    test('a condition followed by a real question still matches on a pause',
        () {
      expect(
        looksLikeQuestion('Když to nevyjde, kdo to zaplatí.', endedOnPause: true),
        isTrue,
      );
      expect(looksLikeQuestion('Jestli to stihneme do pátku, to nevím.'),
          isTrue);
    });

    test('"víte, že" and "zdá se, že" are statements even on a pause', () {
      for (final text in ['Víte, že to nefunguje.', 'Zdá se, že to funguje.']) {
        expect(looksLikeQuestion(text), isFalse, reason: text);
        expect(looksLikeQuestion(text, endedOnPause: true), isFalse,
            reason: text);
      }
      expect(looksLikeQuestion('Zda se nám to vyplatí.'), isTrue);
    });

    test('Czech "do" is a preposition, English "do" an auxiliary', () {
      expect(looksLikeQuestion('Do pátku to pošlu.', endedOnPause: true),
          isFalse);
      expect(looksLikeQuestion('Do we have the budget for it.'), isTrue);
      expect(looksLikeQuestion('Do you know the deadline.'), isTrue);
    });

    test('a preposition in front of the interrogative', () {
      expect(looksLikeQuestion('Na kdy to plánujeme.'), isTrue);
      expect(looksLikeQuestion('S kým to máme probrat.'), isTrue);
      expect(looksLikeQuestion('Za kolika dny to bude.'), isTrue);
    });

    test('idioms that open with an interrogative', () {
      for (final text in [
        'Co se týče rozpočtu, jsme v plánu.',
        'Jak víte, rozpočet je napjatý.',
        'Jak jsem říkal, začneme v pondělí.',
        'Mohl jsem to udělat líp.',
      ]) {
        expect(looksLikeQuestion(text), isFalse, reason: text);
        expect(looksLikeQuestion(text, endedOnPause: true), isFalse,
            reason: text);
      }
      expect(looksLikeQuestion('Mohl bys to poslat.'), isTrue);
    });

    test('an ellipsis separates sentences', () {
      expect(looksLikeQuestion('Takže… kdo to podepíše.'), isTrue);
    });
  });

  group('chunkEndedOnPause', () {
    const max = Duration(milliseconds: 18500);

    test('a short chunk was cut by the silence detector', () {
      expect(chunkEndedOnPause(const Duration(seconds: 8), max), isTrue);
    });

    test('a chunk at the fast profile hard cap was not', () {
      expect(chunkEndedOnPause(const Duration(seconds: 20), max), isFalse);
    });

    test('a chunk at the normal profile hard cap was not', () {
      expect(chunkEndedOnPause(const Duration(seconds: 30), max), isFalse);
    });
  });
}
