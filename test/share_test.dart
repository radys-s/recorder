import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/share.dart';

void main() {
  group('shareBody', () {
    test('puts the lesson name above the text', () {
      expect(
        shareBody(title: 'Počítačové sítě', content: 'Téma: Směrování'),
        'Počítačové sítě\n\nTéma: Směrování',
      );
    });

    test('trims what the generator left around the text', () {
      expect(
        shareBody(title: ' Čeština ', content: '\n\nBabička\n\n'),
        'Čeština\n\nBabička',
      );
    });

    test('an untitled note shares just its text', () {
      expect(shareBody(title: '', content: 'Poznámka'), 'Poznámka');
    });

    test('a title with nothing under it is still worth sharing', () {
      expect(shareBody(title: 'Dějepis', content: '   '), 'Dějepis');
    });
  });
}
