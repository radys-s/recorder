import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/context_builder.dart';

String _words(int n, String word) => List.filled(n, word).join(' ');

void main() {
  group('buildLessonContext', () {
    test('no material leaves only the transcript tail', () {
      final ctx = buildLessonContext(
        material: const LessonMaterial(),
        transcript: '  Dobrý den, začneme.  ',
        focus: 'začneme',
      );
      expect(ctx.material, isEmpty);
      expect(ctx.tail, 'Dobrý den, začneme.');
      expect(ctx.cardIds, isEmpty);
    });

    test('never exceeds the budget, however much there is', () {
      final material = LessonMaterial(
        subjectName: 'Čeština',
        globalRules: _words(400, 'stručně'),
        subjectRules: _words(400, 'citace'),
        lessonRules: _words(400, 'příklady'),
        chatRules: [for (var i = 0; i < 30; i++) _words(40, 'pravidlo$i')],
        chatContext: [for (var i = 0; i < 30; i++) _words(60, 'úryvek$i')],
        cards: [
          for (var i = 0; i < 8; i++)
            LessonCard(
              id: i,
              title: 'Karta $i',
              content: List.filled(20, _words(90, 'Viktorka bloudila')).join('\n\n'),
              summary: _words(80, 'shrnutí'),
              pinned: i.isEven,
            ),
        ],
      );
      for (final budget in [ContextBudget.automatic, ContextBudget.direct]) {
        final ctx = buildLessonContext(
          material: material,
          transcript: _words(5000, 'slovo'),
          focus: 'Viktorka bloudila lesem',
          budget: budget,
        );
        // One token of rounding per part at most.
        expect(ctx.tokens, lessThanOrEqualTo(budget.total + 2));
        expect(ctx.material, contains('Subject: Čeština'));
      }
    });

    test('rules print global → subject → lesson → chat, newest kept first', () {
      final ctx = buildLessonContext(
        material: const LessonMaterial(
          globalRules: 'Piš česky',
          subjectRules: 'Uváděj autora',
          lessonRules: 'Jednou větou',
          chatRules: ['Bez příkladů', 'S příkladem'],
        ),
        transcript: '',
        focus: '',
      );
      final m = ctx.material;
      final order = [
        'Everywhere: Piš česky',
        'This subject: Uváděj autora',
        'This lesson: Jednou větou',
        'Said in class: Bez příkladů',
        'Said in class: S příkladem',
      ].map(m.indexOf).toList();
      expect(order, everyElement(greaterThanOrEqualTo(0)));
      expect(order, orderedEquals([...order]..sort()));

      final tight = buildLessonContext(
        material: LessonMaterial(
          globalRules: _words(60, 'starší'),
          chatRules: const ['Nejnovější pravidlo'],
        ),
        transcript: '',
        focus: '',
        budget: const ContextBudget(rules: 60, cards: 0, chat: 0, tail: 10),
      );
      expect(tight.material, contains('Nejnovější pravidlo'));
      expect(tight.material, isNot(contains('starší')));
    });

    test('a pinned card always joins; an unpinned one only when talked about',
        () {
      const pinned = LessonCard(
        id: 1,
        title: 'Máj',
        content: 'Lyrickoepická báseň Karla Hynka Máchy.',
        summary: 'Romantická báseň, Vilém a Jarmila.',
        pinned: true,
      );
      const other = LessonCard(
        id: 2,
        title: 'Babička',
        content: 'Viktorka bloudila lesem kolem splavu a zpívala.',
      );
      final quiet = buildLessonContext(
        material: const LessonMaterial(cards: [pinned, other]),
        transcript: '',
        focus: 'Dnes budeme psát diktát.',
      );
      expect(quiet.cardIds, {'Máj': 1});
      expect(quiet.material, contains('Vilém a Jarmila'));
      expect(quiet.material, isNot(contains('Viktorka')));

      final talked = buildLessonContext(
        material: const LessonMaterial(cards: [pinned, other]),
        transcript: '',
        focus: 'Proč Viktorka bloudila lesem u splavu?',
      );
      expect(talked.cardIds, {'Máj': 1, 'Babička': 2});
      // Pinned cards print first.
      expect(talked.material.indexOf('[Máj]'),
          lessThan(talked.material.indexOf('[Babička]')));
    });

    test('a share nobody used rolls over to the transcript', () {
      final transcript = _words(3000, 'slovo');
      final bare = buildLessonContext(
        material: const LessonMaterial(),
        transcript: transcript,
        focus: '',
      );
      expect(bare.tail.length, greaterThan(ContextBudget.automatic.tail * 3));
      expect(bare.tail.length,
          lessThanOrEqualTo(ContextBudget.automatic.total * 3));
    });
  });

  test('cardIdFor tolerates case, whitespace and quotes', () {
    const ctx = LessonContext(material: '', tail: '', cardIds: {'Babička': 7});
    expect(ctx.cardIdFor('babička'), 7);
    expect(ctx.cardIdFor(' „Babička“ '), 7);
    expect(ctx.cardIdFor('"Babička"'), 7);
    expect(ctx.cardIdFor('[Babička]'), 7);
    expect(ctx.cardIdFor('Máj'), isNull);
    expect(ctx.cardIdFor(''), isNull);
  });

  test('chunkCardContent keeps every piece under the limit', () {
    final content = [
      'Krátký odstavec.',
      'Druhý krátký.',
      List.filled(40, 'Dlouhá věta o Viktorce, která bloudí.').join(' '),
      'x' * 1500,
    ].join('\n\n');
    final chunks = chunkCardContent(content, maxChars: 200);
    expect(chunks, isNotEmpty);
    for (final c in chunks) {
      expect(c.length, lessThanOrEqualTo(200));
    }
    // Short neighbours are merged.
    expect(chunks.first, startsWith('Krátký odstavec.\nDruhý krátký.'));
  });

  test('tailOf starts on a whole word', () {
    expect(tailOf('jedna dva tři', 100), 'jedna dva tři');
    expect(tailOf('jedna dva tři', 6), 'tři');
  });
}
