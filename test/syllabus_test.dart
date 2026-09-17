import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/syllabus.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';

SyllabusTopic topic(
  int id,
  String title, {
  String? terms,
  int? from,
  int? to,
  int? ord,
}) => SyllabusTopic(
  id: id,
  subjectId: 1,
  ord: ord ?? id,
  title: title,
  terms: terms,
  monthFrom: from,
  monthTo: to ?? from,
  source: SyllabusSource.pasted,
  createdAt: DateTime(2026, 9, 1),
);

void main() {
  group('parseSyllabus', () {
    test('reads topics with terms and months', () {
      final topics = parseSyllabus('''
Tady je plán:
{"topics": [
  {"title": "Model OSI", "description": "Vrstvy", "terms": ["OSI", "TCP/IP", "osi"], "month_from": "září", "month_to": 10},
  {"title": "Směrování", "terms": "RIP, OSPF; směrovací tabulka", "month_from": "v listopadu"},
  {"title": "  "},
  {"title": "model osi"},
  "nesmysl"
]}''');
      expect(topics, hasLength(2));
      expect(topics[0].title, 'Model OSI');
      expect(topics[0].terms, ['OSI', 'TCP/IP']);
      expect((topics[0].monthFrom, topics[0].monthTo), (9, 10));
      expect(topics[1].terms, ['RIP', 'OSPF', 'směrovací tabulka']);
      expect((topics[1].monthFrom, topics[1].monthTo), (11, 11));
      expect(topics[1].description, isNull);
    });

    test('garbage gives no topics', () {
      expect(parseSyllabus('nevím'), isEmpty);
      expect(parseSyllabus('{"topics": "x"}'), isEmpty);
    });

    test('clips long titles', () {
      final long = 'a' * 400;
      expect(
        parseSyllabus('{"topics":[{"title":"$long"}]}').single.title.length,
        kSyllabusTitleMaxChars,
      );
    });
  });

  group('parseMonth', () {
    test('numbers and numeric strings', () {
      expect(parseMonth(9), 9);
      expect(parseMonth(9.0), 9);
      expect(parseMonth('9.'), 9);
      expect(parseMonth(' 12 '), 12);
      expect(parseMonth(13), isNull);
      expect(parseMonth(0), isNull);
    });

    test('Czech and English names in any form', () {
      expect(parseMonth('Září'), 9);
      expect(parseMonth('cervenec'), 7);
      expect(parseMonth('v červenci'), 7);
      expect(parseMonth('června'), 6);
      expect(parseMonth('červen'), 6);
      expect(parseMonth('v únoru'), 2);
      expect(parseMonth('prosinec'), 12);
      expect(parseMonth('October'), 10);
      expect(parseMonth('nikdy'), isNull);
      expect(parseMonth(null), isNull);
    });
  });

  test('parseTerms caps and drops long terms', () {
    expect(parseTerms([for (var i = 0; i < 30; i++) 't$i']), hasLength(15));
    expect(parseTerms(['x' * 81, 'ok']), ['ok']);
    expect(parseTerms(42), isEmpty);
  });

  test('schoolMonthIndex runs September to June', () {
    expect(schoolMonthIndex(9), 0);
    expect(schoolMonthIndex(12), 3);
    expect(schoolMonthIndex(1), 4);
    expect(schoolMonthIndex(6), 9);
    expect(schoolMonthIndex(7), 9);
    expect(schoolMonthIndex(8), 0);
  });

  group('currentTopics', () {
    test('range across the new year contains January', () {
      final topics = [
        topic(1, 'OSI', from: 9, to: 10),
        topic(2, 'Směrování', from: 11, to: 2),
        topic(3, 'Bezdrát', from: 3, to: 6),
      ];
      expect(currentTopics(topics, DateTime(2027, 1, 15)).map((t) => t.id), [
        2,
      ]);
    });

    test('gap in the plan takes the nearest range', () {
      final topics = [
        topic(1, 'OSI', from: 9, to: 9),
        topic(2, 'Směrování', from: 12, to: 12),
      ];
      // October is one month from September, two from December.
      expect(currentTopics(topics, DateTime(2026, 10, 10)).single.id, 1);
      // Summer counts as the nearest end of the year.
      expect(currentTopics(topics, DateTime(2026, 8, 20)).single.id, 1);
    });

    test('overlapping ranges return all of them in plan order', () {
      final topics = [
        topic(2, 'B', from: 10, to: 11, ord: 1),
        topic(1, 'A', from: 9, to: 10, ord: 0),
      ];
      expect(currentTopics(topics, DateTime(2026, 10, 5)).map((t) => t.title), [
        'A',
        'B',
      ]);
    });

    test('without months the plan is spread over the year', () {
      final topics = [for (var i = 0; i < 10; i++) topic(i, 'T$i')];
      expect(currentTopics(topics, DateTime(2026, 9, 1)).single.id, 0);
      expect(currentTopics(topics, DateTime(2027, 1, 20)).single.id, 4);
      expect(currentTopics(topics, DateTime(2027, 6, 30)).single.id, 9);
      expect(currentTopics(topics, DateTime(2027, 7, 10)).single.id, 9);
      expect(currentTopics(topics, DateTime(2026, 8, 10)).single.id, 0);
    });

    test('empty plan', () {
      expect(currentTopics(const [], DateTime(2026, 9, 1)), isEmpty);
    });
  });

  group('detectTopic', () {
    final osi = topic(1, 'Model OSI', terms: 'vrstva, protokol, zapouzdření');
    final routing = topic(
      2,
      'Směrování',
      terms: 'RIP, OSPF, směrovací tabulka, metrika',
    );

    test('a clear lead wins, abbreviations count', () {
      expect(
        detectTopic(
          [osi, routing],
          'Protokol ospf si počítá metriku jinak než rip, '
          'podívejte se do směrovací tabulky.',
        )?.id,
        2,
      );
    });

    test('a narrow lead keeps the current topic', () {
      expect(
        detectTopic(
          [osi, routing],
          'Každá vrstva má svůj protokol a metriku.',
          current: routing,
        )?.id,
        2,
      );
    });

    test('too few hits keeps current, even null', () {
      expect(detectTopic([osi, routing], 'Dobrý den, sedněte si.'), isNull);
      expect(detectTopic([osi, routing], ''), isNull);
    });

    test('common short Czech words are not topic keys', () {
      final keys = topicKeys(topic(3, 'Sítě a jejich IP adresy', terms: 'DNS'));
      expect(keys, containsAll(['ip', 'dns']));
      expect(keys, isNot(contains('a')));
    });
  });
}
