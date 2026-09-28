import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/daos/study_cards_dao.dart';
import 'package:recorder/data/db/tables/study_cards_table.dart';
import 'package:recorder/learning/study_items.dart';

const _notes = '''
Téma:
Směrování v sítích

Klíčové pojmy:
- **OSPF** – link-state směrovací protokol
- RIP: počítá počet skoků
- Tohle je celá věta bez definice
- Velmi dlouhý název pojmu který má moc slov – x y z
- DV – ab

Co si zapamatovat (může být v testu):
- OSPF používá Dijkstrův algoritmus.
- RIP má limit 15 skoků.

Domácí úkol:
- nic
''';

void main() {
  test('key terms with a definition become cards', () {
    expect(termCardsFromNotes(_notes), const [
      StudyItem('OSPF', 'link-state směrovací protokol', StudySource.terms),
      StudyItem('RIP', 'počítá počet skoků', StudySource.terms),
    ]);
  });

  test('the remember section is read as written, and nothing after it', () {
    expect(rememberBulletsFromNotes(_notes), [
      'OSPF používá Dijkstrův algoritmus.',
      'RIP má limit 15 skoků.',
    ]);
    expect(rememberBulletsFromNotes('Téma:\n- a'), isEmpty);
  });

  test('model pairs: malformed items skipped, repeats dropped, capped', () {
    final raw =
        '''{"cards": [
      {"q": "Jaký algoritmus používá OSPF?", "a": "Dijkstrův"},
      {"q": "jaky algoritmus pouziva OSPF", "a": "dup"},
      {"q": "", "a": "x"},
      {"q": 1, "a": "x"},
      "nic",
      ${List.generate(20, (i) => '{"q": "Otázka $i?", "a": "$i"}').join(',')}
    ]}''';
    final out = parseStudyPairs(raw, StudySource.remember);
    expect(out, hasLength(kMaxGeneratedStudyCards));
    expect(out.first.front, 'Jaký algoritmus používá OSPF?');
    expect(out.every((i) => i.source == StudySource.remember), isTrue);
    expect(out.where((i) => i.back == 'dup'), isEmpty);
  });

  test('a reply that is not JSON gives nothing', () {
    expect(parseStudyPairs('Nevím.', StudySource.remember), isEmpty);
    expect(parseStudyPairs('{"cards": {}}', StudySource.remember), isEmpty);
  });
}
