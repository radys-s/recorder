import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/course_overview.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/syllabus_topics_table.dart';

SyllabusTopic _topic(int id, String title, int month) => SyllabusTopic(
  id: id,
  subjectId: 1,
  ord: id - 1,
  title: title,
  monthFrom: month,
  monthTo: month,
  source: SyllabusSource.pasted,
  createdAt: DateTime(2026),
);

Meeting _lesson(int id, DateTime at, {int? topicId}) => Meeting(
  id: id,
  title: 'Hodina $id',
  createdAt: at,
  interrupted: false,
  topicId: topicId,
);

/// Počítačové sítě, one topic a month from September to February.
final _plan = [
  _topic(1, 'OSI', 9),
  _topic(2, 'TCP/IP', 10),
  _topic(3, 'Adresace', 10),
  _topic(4, 'Směrování', 11),
  _topic(5, 'VLAN', 12),
  _topic(6, 'Wi-Fi', 1),
  _topic(7, 'Bezpečnost', 2),
];

final _now = DateTime(2026, 12, 10);

void main() {
  test('covered, missed, current and upcoming against the plan', () {
    final overview = courseOverview(
      topics: _plan,
      lessons: [
        // No topic picked: October's first topic.
        _lesson(1, DateTime(2026, 10, 5)),
        _lesson(2, DateTime(2026, 12, 1), topicId: 4),
      ],
      now: _now,
    );

    expect(
      {for (final t in overview.topics) t.topic.title: t.coverage},
      {
        'OSI': TopicCoverage.beforeRecording,
        'TCP/IP': TopicCoverage.covered,
        'Adresace': TopicCoverage.missed,
        'Směrování': TopicCoverage.covered,
        'VLAN': TopicCoverage.current,
        'Wi-Fi': TopicCoverage.upcoming,
        'Bezpečnost': TopicCoverage.upcoming,
      },
    );
    expect(overview.topics[1].lessons.map((m) => m.id), [1]);
    expect(overview.topics[3].lessons.map((m) => m.id), [2]);
    expect(overview.topics[4].isCurrent, isTrue);
    expect(overview.topics.where((t) => t.isCurrent), hasLength(1));
    expect(overview.total, 7);
    expect(overview.count(TopicCoverage.covered), 2);
    expect(overview.count(TopicCoverage.missed), 1);
  });

  test('a lesson on the current topic makes it covered and still current', () {
    final overview = courseOverview(
      topics: _plan,
      lessons: [_lesson(1, DateTime(2026, 12, 5))],
      now: _now,
    );
    final vlan = overview.topics[4];
    expect(vlan.coverage, TopicCoverage.covered);
    expect(vlan.isCurrent, isTrue);
    // Everything before the first recorded topic predates the app.
    expect(
      overview.topics.take(4).map((t) => t.coverage).toSet(),
      {TopicCoverage.beforeRecording},
    );
  });

  test('without lessons nothing is missing', () {
    final overview = courseOverview(topics: _plan, lessons: const [], now: _now);
    expect(overview.count(TopicCoverage.missed), 0);
    expect(overview.count(TopicCoverage.beforeRecording), 4);
    expect(overview.count(TopicCoverage.current), 1);
    expect(overview.count(TopicCoverage.upcoming), 2);
  });

  test('an empty plan gives an empty overview', () {
    final overview = courseOverview(
      topics: const [],
      lessons: [_lesson(1, DateTime(2026, 10, 5))],
      now: _now,
    );
    expect(overview.topics, isEmpty);
    expect(overview.total, 0);
  });

  test('topics follow the plan order and lessons run oldest first', () {
    final overview = courseOverview(
      topics: _plan.reversed.toList(),
      lessons: [
        _lesson(3, DateTime(2026, 10, 20), topicId: 2),
        _lesson(1, DateTime(2026, 10, 1), topicId: 2),
        _lesson(2, DateTime(2026, 10, 8), topicId: 2),
      ],
      now: _now,
    );
    expect(overview.topics.first.topic.title, 'OSI');
    expect(overview.topics[1].lessons.map((m) => m.id), [1, 2, 3]);
  });

  test('a picked topic that left the plan falls back to the date', () {
    final overview = courseOverview(
      topics: _plan,
      lessons: [_lesson(1, DateTime(2026, 11, 3), topicId: 99)],
      now: _now,
    );
    expect(overview.topics[3].coverage, TopicCoverage.covered);
  });

  test('labels', () {
    expect(coverageLabel(TopicCoverage.covered), 'Probráno');
    expect(coverageLabel(TopicCoverage.current), 'Teď');
    expect(coverageLabel(TopicCoverage.missed), 'Chybí záznam');
    expect(coverageLabel(TopicCoverage.upcoming), 'Čeká');
    expect(coverageLabel(TopicCoverage.beforeRecording), 'Před nahráváním');
  });
}
