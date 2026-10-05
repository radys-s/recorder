import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/photo_questions.dart';
import 'package:recorder/ai/photo_text_service.dart';

void main() {
  group('extractQuestions', () {
    test('numbered worksheet', () {
      const text = '''
Pracovní list – Babička
1) Kdo je hlavní postava díla?
2) Vysvětli pojem idyla.
3) Popiš vztah Viktorky a Babičky.''';
      expect(extractQuestions(text), [
        'Kdo je hlavní postava díla?',
        'Vysvětli pojem idyla.',
        'Popiš vztah Viktorky a Babičky.',
      ]);
    });

    test('lettered and bulleted items, markers stripped', () {
      const text = '''
a) Co je to lyrickoepický žánr?
b. Jaký je rozdíl mezi povídkou a novelou?
- Uveď tři příklady realismu.''';
      expect(extractQuestions(text), [
        'Co je to lyrickoepický žánr?',
        'Jaký je rozdíl mezi povídkou a novelou?',
        'Uveď tři příklady realismu.',
      ]);
    });

    test('a plain question line with no number', () {
      expect(extractQuestions('Proč se říká, že Máj je básnický?'), [
        'Proč se říká, že Máj je básnický?',
      ]);
    });

    test('statements, titles and facts are not questions', () {
      const text = '''
Realismus v české literatuře
- vznikl v druhé polovině 19. století
- hlavní představitelé: Němcová, Neruda
1. Božena Němcová se narodila ve Vídni.''';
      expect(extractQuestions(text), isEmpty);
    });

    test('no text, short noise and blank lines give nothing', () {
      expect(extractQuestions(''), isEmpty);
      expect(extractQuestions('\n\n  \n'), isEmpty);
      expect(extractQuestions('a?\nb\n--'), isEmpty);
    });

    test('duplicates collapse and the list is capped', () {
      final many = [
        for (var i = 0; i < 20; i++) '${i + 1}) Co je pojem číslo $i?',
        '1) Co je pojem číslo 0?',
      ].join('\n');
      final found = extractQuestions(many);
      expect(found.length, kMaxPhotoQuestions);
      expect(found.toSet().length, found.length);
    });

    test('English tasks work too', () {
      expect(
        extractQuestions('1. Explain the greenhouse effect.\n2. What is CO2?'),
        ['Explain the greenhouse effect.', 'What is CO2?'],
      );
    });

    test('diacritic-less typing of task verbs', () {
      expect(extractQuestions('1) Vysvetli pojem realismus.'), [
        'Vysvetli pojem realismus.',
      ]);
    });
  });

  group('parseBoardReading questions', () {
    test('reads the list and trims it', () {
      final r = parseBoardReading(
        '{"text": "1) Kdo?", "description": "", '
        '"questions": [" Kdo byl Proško? ", "", 3, "Co je idyla?"]}',
      )!;
      expect(r.questions, ['Kdo byl Proško?', 'Co je idyla?']);
    });

    test('a missing or malformed field means none, never a failure', () {
      expect(
        parseBoardReading('{"text": "Babička", "description": "tabule"}')!
            .questions,
        isEmpty,
      );
      expect(
        parseBoardReading(
          '{"text": "Babička", "description": "", "questions": "Kdo?"}',
        )!.questions,
        isEmpty,
      );
    });

    test('capped at the limit', () {
      final qs = [for (var i = 0; i < 20; i++) '"Otázka $i?"'].join(',');
      final r = parseBoardReading(
        '{"text": "x", "description": "", "questions": [$qs]}',
      )!;
      expect(r.questions.length, kMaxPhotoQuestions);
    });
  });
}
