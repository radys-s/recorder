import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/stt/refined_transcriber.dart';
import 'package:recorder/stt/transcript_sanitizer.dart';

void main() {
  group('normalizeForArtifactMatch', () {
    test('folds Czech diacritics', () {
      expect(
        normalizeForArtifactMatch('Děkuji za pozornost.'),
        'dekuji za pozornost',
      );
      expect(normalizeForArtifactMatch('Překlad titulků'), 'preklad titulku');
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

    test('drops the known standalone URL hallucination', () {
      expect(sanitizeTranscript('www.hradeckralove.org'), '');
      expect(sanitizeTranscript('WWW.HRADECKRALOVE.ORG.'), '');
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

    test('keeps a URL said as part of a sentence', () {
      const text = 'Materiály najdete na www.example.org po hodině.';
      expect(sanitizeTranscript(text), text);
    });
  });

  group('filterTranscriptUrlArtifact', () {
    test('drops a generic standalone domain only with weak evidence', () {
      final filtered = filterTranscriptUrlArtifact(
        'www.example.org',
        confidence: -1.1,
        voicedMs: 100,
        durationMs: 4000,
      );

      expect(filtered.text, '');
      expect(filtered.reason, 'suspect_url_artifact');
    });

    test('keeps a generic standalone domain when the audio is credible', () {
      final filtered = filterTranscriptUrlArtifact(
        'www.example.org',
        confidence: -0.2,
        voicedMs: 3000,
        durationMs: 4000,
      );

      expect(filtered.text, 'www.example.org');
      expect(filtered.removed, isFalse);
    });
  });

  group('cleanGeminiTranscript', () {
    test('applies the same known URL artifact guard after refinement', () {
      expect(cleanGeminiTranscript('www.hradeckralove.org'), '');
    });
  });
}
