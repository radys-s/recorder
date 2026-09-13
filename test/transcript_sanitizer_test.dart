import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/stt/transcript_sanitizer.dart';

void main() {
  group('normalizeForArtifactMatch', () {
    test('folds Czech diacritics', () {
      expect(
        normalizeForArtifactMatch('Děkuji za pozornost.'),
        'dekuji za pozornost',
      );
      expect(
        normalizeForArtifactMatch('Překlad titulků'),
        'preklad titulku',
      );
    });

    test('collapses whitespace and strips punctuation', () {
      expect(normalizeForArtifactMatch('  Ahoj,\n  světe!  '), 'ahoj svete');
    });
  });

  group('sanitizeTranscript — whole text is an artifact', () {
    test('Czech sign-off', () {
      expect(sanitizeTranscript('Děkuji za pozornost.'), '');
      expect(sanitizeTranscript('Děkuji za sledování!'), '');
    });

    test('Czech subtitle credit, with and without a name', () {
      expect(sanitizeTranscript('Titulky vytvořil Jan Novák'), '');
      expect(sanitizeTranscript('Titulky vytvořil.'), '');
      expect(
        sanitizeTranscript('Titulky pro vás vytvořil někdo úplně jiný.'),
        '',
      );
    });

    test('English artifacts', () {
      expect(sanitizeTranscript('you'), '');
      expect(sanitizeTranscript('Thank you.'), '');
      expect(sanitizeTranscript('Thanks for watching!'), '');
      expect(sanitizeTranscript('Subtitles by the Amara.org community'), '');
    });

    test('two stacked artifacts still leave nothing', () {
      expect(
        sanitizeTranscript('Děkuji za pozornost. Titulky vytvořil Jan Novák.'),
        '',
      );
    });

    test('empty and whitespace-only input', () {
      expect(sanitizeTranscript(''), '');
      expect(sanitizeTranscript('   \n  '), '');
    });
  });

  group('sanitizeTranscript — trailing artifact', () {
    test('strips only the last sentence', () {
      expect(
        sanitizeTranscript(
          'Domluvili jsme se na pátek. Karel pošle podklady. '
          'Titulky vytvořil Jan Novák',
        ),
        'Domluvili jsme se na pátek. Karel pošle podklady.',
      );
    });

    test('strips a trailing sign-off after real speech', () {
      expect(
        sanitizeTranscript('Rozpočet je dva miliony. Děkuji za pozornost.'),
        'Rozpočet je dva miliony.',
      );
    });

    test('strips several stacked trailing artifacts at once', () {
      expect(
        sanitizeTranscript(
          'Sejdeme se v úterý. Děkuji za pozornost. Titulky vytvořil ČT.',
        ),
        'Sejdeme se v úterý.',
      );
    });
  });

  group('sanitizeTranscript — leaves real speech alone', () {
    test('an artifact phrase in the middle is kept', () {
      const text =
          'Děkuji za pozornost. A teď se pojďme bavit o rozpočtu na příští rok.';
      expect(sanitizeTranscript(text), text);
    });

    test('a prefix artifact is not matched inside a real sentence', () {
      const text = 'You know what I mean, the deadline is next Tuesday.';
      expect(sanitizeTranscript(text), text);
    });

    test('ordinary Czech is untouched apart from trimming', () {
      expect(
        sanitizeTranscript('  Musíme to stihnout do konce měsíce.  '),
        'Musíme to stihnout do konce měsíce.',
      );
    });

    test('a single non-artifact sentence survives', () {
      expect(sanitizeTranscript('Ano.'), 'Ano.');
    });
  });
}
