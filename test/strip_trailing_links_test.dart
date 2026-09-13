import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/web_answer_service.dart';

void main() {
  group('stripTrailingLinks', () {
    test('drops the block of bare URLs the model appends', () {
      // Verbatim shape of card 245 from the M20 verification run.
      const raw = 'Základní úroková sazba České národní banky je 3,75 % a od '
          'června 2026 zůstává na této úrovni.\n\n'
          'https://www.fintag.cz/2026/08/06/cnb-sazby-nezmenila/\n'
          'https://www.cnb.cz/cs/menova-politika/br-zapisy-z-jednani/';
      expect(
        stripTrailingLinks(raw),
        'Základní úroková sazba České národní banky je 3,75 % a od června '
        '2026 zůstává na této úrovni.',
      );
    });

    test('drops a bulleted and a bracketed link line', () {
      const raw = 'Sazba je 3,75 %.\n'
          '- https://example.com/a\n'
          '<https://example.com/b>\n'
          '* (https://example.com/c).';
      expect(stripTrailingLinks(raw), 'Sazba je 3,75 %.');
    });

    test('leaves a link the sentence is actually about', () {
      const raw = 'Sazby jsou zveřejněny na https://www.cnb.cz a mění se '
          'osmkrát ročně.';
      expect(stripTrailingLinks(raw), raw);
    });

    test('leaves an answer with no links at all alone', () {
      const raw = 'Zbývá přibližně 1,2 milionu korun.';
      expect(stripTrailingLinks(raw), raw);
    });

    test('an answer that is nothing but links becomes empty', () {
      // Which the caller already treats as "no answer" and drops.
      expect(stripTrailingLinks('https://example.com/a\nhttps://b.example'), '');
    });
  });
}
