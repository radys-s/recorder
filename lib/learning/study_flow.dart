import 'package:intl/intl.dart';

import '../data/db/app_database.dart';
import '../data/db/tables/study_cards_table.dart';

/// Pure rules of the study flow: what to do next on a subject, where a card
/// came from and how to name a day. Kept apart from the widgets so the
/// decisions can be tested without a screen.

/// What the subject's Přehled should push the student towards.
enum StudyStep {
  /// Cards are due today.
  reviewDue,

  /// No lesson recorded yet.
  recordLesson,

  /// Lessons exist, but none has výpisky.
  makeNotes,

  /// Some lesson has výpisky and no cards yet.
  makeCards,

  /// Material is in place and nothing is due: try yourself before the test.
  examPrep,
}

/// The one thing to do next, with the sentence that explains why.
class StudyRecommendation {
  const StudyRecommendation(this.step, this.title, this.subtitle);

  final StudyStep step;
  final String title;
  final String subtitle;
}

String _cards(int n) =>
    n == 1 ? '1 kartička' : (n >= 2 && n <= 4 ? '$n kartičky' : '$n kartiček');

String _lessons(int n) =>
    n == 1 ? '1 hodina' : (n >= 2 && n <= 4 ? '$n hodiny' : '$n hodin');

/// Picks the next step for a subject from what it holds.
///
/// [lessonsWithNotes] counts lessons that have výpisky; [lessonsToCard] those
/// among them that gave no card yet. Order matters: what is already due beats
/// making more material, and making material beats testing on nothing.
StudyRecommendation recommendStudyStep({
  required int lessons,
  required int lessonsWithNotes,
  required int lessonsToCard,
  required int cards,
  required int due,
}) {
  if (due > 0) {
    return StudyRecommendation(
      StudyStep.reviewDue,
      'Zopakuj ${_cards(due)}',
      'Dnes jsou na řadě. Zabere to pár minut.',
    );
  }
  if (lessons == 0) {
    return const StudyRecommendation(
      StudyStep.recordLesson,
      'Nahraj první hodinu',
      'Z výpisků hodiny se pak udělají kartičky na opakování.',
    );
  }
  if (lessonsWithNotes == 0) {
    return StudyRecommendation(
      StudyStep.makeNotes,
      'Vytvoř výpisky z hodiny',
      lessons == 1
          ? 'Hodina zatím nemá výpisky, ze kterých by šlo učit.'
          : '${_lessons(lessons)} zatím nemá výpisky, ze kterých by šlo učit.',
    );
  }
  if (lessonsToCard > 0) {
    return StudyRecommendation(
      StudyStep.makeCards,
      'Udělej kartičky z výpisků',
      lessonsToCard == 1
          ? 'Jedna hodina má výpisky, ale žádné kartičky.'
          : '${_lessons(lessonsToCard)} má výpisky, ale žádné kartičky.',
    );
  }
  return StudyRecommendation(
    StudyStep.examPrep,
    'Vyzkoušej se před testem',
    cards == 0
        ? 'Z výpisků a plánu se sestaví shrnutí a kvíz.'
        : 'Dnes nic nečeká. Kvíz z výpisků ukáže, co ještě nesedí.',
  );
}

/// What a lesson holds for learning, as one line under its title: whether it
/// has výpisky, and how many cards came out of it.
String lessonStudyLine({
  required bool hasNotes,
  required int cards,
  required int due,
}) {
  if (cards == 0) return hasNotes ? 'Výpisky · bez kartiček' : 'Bez výpisků';
  final count = _cards(cards);
  final today = due > 0 ? ' · dnes $due' : '';
  return hasNotes ? 'Výpisky · $count$today' : '$count$today';
}

const _weekdayIn = [
  'v pondělí',
  'v úterý',
  've středu',
  've čtvrtek',
  'v pátek',
  'v sobotu',
  'v neděli',
];

/// „dnes", „zítra", „v pátek", then a date: when a card is next due, without
/// the clock time that means nothing for a daily review.
String describeDueDay(DateTime due, DateTime now) {
  final days = DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  if (days <= 0) return 'dnes';
  if (days == 1) return 'zítra';
  if (days < 7) return _weekdayIn[due.weekday - 1];
  return DateFormat('d. M.').format(due);
}

/// Whether a card's text was written by a model rather than by the student.
bool studyCardFromAi(StudyCard card) => card.source != StudySource.manual;

/// Where a card came from, as one line the student can check against.
///
/// [lessonDate] is when the source lesson happened, when the card still has
/// one. A card made by a model says so: it is a study aid drawn from the
/// výpisky, not a verified fact.
String studyCardProvenance(StudyCard card, {DateTime? lessonDate}) {
  switch (card.source) {
    case StudySource.manual:
      return 'Přidáno ručně';
    case StudySource.quiz:
      return 'Chyba z testu „Před testem". Otázku vytvořila AI.';
    case StudySource.terms:
      final day = lessonDate == null
          ? 'z výpisků'
          : 'z výpisků hodiny ${DateFormat('d. M.').format(lessonDate)}';
      return 'Pojem $day — výpisky vytvořila AI, ověř je.';
    case StudySource.remember:
      final day = lessonDate == null
          ? 'z výpisků'
          : 'z výpisků hodiny ${DateFormat('d. M.').format(lessonDate)}';
      return 'Kartičku vytvořila AI $day — ověř ji ve výpiscích.';
  }
}
