import '../data/db/app_database.dart';
import 'syllabus.dart';

/// Where a topic of the thematic plan stands against the recorded lessons.
enum TopicCoverage {
  /// At least one recorded lesson was about it.
  covered,

  /// The plan puts it now and no lesson has covered it yet.
  current,

  /// Past in the plan, after recording started, and no lesson about it.
  missed,

  /// Later in the plan.
  upcoming,

  /// Past in the plan, but before the first recorded lesson — nothing is
  /// missing, the app simply was not there yet.
  beforeRecording,
}

/// One topic with the lessons that covered it, oldest first.
class TopicOverview {
  const TopicOverview({
    required this.topic,
    required this.lessons,
    required this.coverage,
    required this.isCurrent,
  });

  final SyllabusTopic topic;
  final List<Meeting> lessons;
  final TopicCoverage coverage;

  /// The plan puts this topic now. A covered topic can be current too.
  final bool isCurrent;
}

class CourseOverview {
  const CourseOverview(this.topics);

  /// In plan order.
  final List<TopicOverview> topics;

  int get total => topics.length;

  int count(TopicCoverage coverage) =>
      topics.where((t) => t.coverage == coverage).length;
}

/// The plan as a timeline: which topics the lessons covered, which the plan
/// has already passed without a lesson, and which are still ahead.
///
/// Each lesson belongs to [lessonTopic] — the topic picked or detected for it,
/// else the plan's topic for its date. "Now" is the plan's topic for [now];
/// topics before the first recorded lesson's topic are not called missing.
CourseOverview courseOverview({
  required List<SyllabusTopic> topics,
  required List<Meeting> lessons,
  required DateTime now,
}) {
  if (topics.isEmpty) return const CourseOverview([]);
  final sorted = [...topics]..sort((a, b) => a.ord.compareTo(b.ord));
  final position = {for (var i = 0; i < sorted.length; i++) sorted[i].id: i};

  final byTopic = <int, List<Meeting>>{};
  for (final lesson in [...lessons]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt))) {
    final topic = lessonTopic(lesson, sorted);
    if (topic != null) (byTopic[topic.id] ??= []).add(lesson);
  }

  final current = {for (final t in currentTopics(sorted, now)) t.id};
  final nowAt = current.map((id) => position[id]!).reduce(_min);
  final startAt = byTopic.isEmpty
      ? null
      : byTopic.keys.map((id) => position[id]!).reduce(_min);

  return CourseOverview([
    for (var i = 0; i < sorted.length; i++)
      TopicOverview(
        topic: sorted[i],
        lessons: byTopic[sorted[i].id] ?? const [],
        isCurrent: current.contains(sorted[i].id),
        coverage: switch (sorted[i]) {
          final t when byTopic.containsKey(t.id) => TopicCoverage.covered,
          final t when current.contains(t.id) => TopicCoverage.current,
          _ when i > nowAt => TopicCoverage.upcoming,
          _ when startAt == null || i < startAt =>
            TopicCoverage.beforeRecording,
          _ => TopicCoverage.missed,
        },
      ),
  ]);
}

int _min(int a, int b) => a < b ? a : b;

/// The Czech word for a status, for the overview and for the summary prompt.
String coverageLabel(TopicCoverage coverage) => switch (coverage) {
  TopicCoverage.covered => 'Probráno',
  TopicCoverage.current => 'Teď',
  TopicCoverage.missed => 'Chybí záznam',
  TopicCoverage.upcoming => 'Čeká',
  TopicCoverage.beforeRecording => 'Před nahráváním',
};
