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

    test('an interrogative in the middle of a sentence does not match', () {
      // The reason clauses are split on sentence terminators and never on
      // commas: these are ordinary Czech statements, and matching them would
      // send nearly every segment to the model.
      expect(looksLikeQuestion('Řekni mi, co potřebuješ.'), isFalse);
      expect(looksLikeQuestion('Nevím, kdy to bude hotové.'), isFalse);
      expect(looksLikeQuestion('Ukázal jsem jim, jak se to dělá.'), isFalse);
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

  group('looksLikeQuestion, after a pause', () {
    // The chunker cut right after this passage, so somebody stopped talking
    // there. That is the only case in which a mid-sentence interrogative is
    // allowed to count.
    test('a trailing rhetorical question with no question mark matches', () {
      const text = 'Musíme to stihnout do konce roku. '
          'A kolik nás to vlastně bude stát.';
      expect(looksLikeQuestion(text), isFalse);
      expect(looksLikeQuestion(text, endedOnPause: true), isTrue);
    });

    test('an interrogative after a comma matches', () {
      const text = 'Zatím nevím, jestli to zvládneme.';
      expect(looksLikeQuestion(text), isFalse);
      expect(looksLikeQuestion(text, endedOnPause: true), isTrue);
    });

    test('only the closing sentence is treated this permissively', () {
      // The pause is evidence about the end of the chunk, not about its
      // middle — otherwise this rule would send nearly every segment to the
      // model, which is what the pre-filter exists to prevent.
      const text = 'Řekni mi, co potřebuješ. Objednávku pošleme zítra.';
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
