/// How well the student remembered a card.
enum ReviewGrade {
  again,
  hard,
  good,
  easy;

  String get label => switch (this) {
    ReviewGrade.again => 'Znovu',
    ReviewGrade.hard => 'Těžké',
    ReviewGrade.good => 'Dobře',
    ReviewGrade.easy => 'Snadno',
  };
}

/// A card's schedule: the part [schedule] reads and writes.
class ReviewState {
  const ReviewState({
    this.ease = 2.5,
    this.intervalDays = 0,
    this.reps = 0,
    this.lapses = 0,
  });

  final double ease;
  final int intervalDays;
  final int reps;
  final int lapses;
}

class ReviewOutcome {
  const ReviewOutcome(this.state, this.dueAt);

  final ReviewState state;
  final DateTime dueAt;
}

const double kMinEase = 1.3;
const double kMaxEase = 3.0;

/// A card graded „Znovu" comes back within the same session.
const Duration kRelearnDelay = Duration(minutes: 10);

/// SM-2 with four grades, the way Anki shapes it.
///
/// „Znovu" resets the streak and brings the card back in ten minutes; the
/// other grades grow the interval (1 day, then 3, then × ease) and nudge the
/// ease. Days are counted from the start of [now]'s day, so a card due
/// „tomorrow" is due at midnight, not 24 hours after the review.
ReviewOutcome schedule(ReviewState s, ReviewGrade grade, DateTime now) {
  if (grade == ReviewGrade.again) {
    return ReviewOutcome(
      ReviewState(
        ease: _clamp(s.ease - 0.2),
        intervalDays: 0,
        reps: 0,
        lapses: s.lapses + (s.reps > 0 ? 1 : 0),
      ),
      now.add(kRelearnDelay),
    );
  }

  final ease = _clamp(switch (grade) {
    ReviewGrade.hard => s.ease - 0.15,
    ReviewGrade.easy => s.ease + 0.15,
    _ => s.ease,
  });

  int days;
  if (s.reps == 0) {
    days = switch (grade) {
      ReviewGrade.hard => 1,
      ReviewGrade.easy => 3,
      _ => 1,
    };
  } else if (s.reps == 1) {
    days = switch (grade) {
      ReviewGrade.hard => 2,
      ReviewGrade.easy => 5,
      _ => 3,
    };
  } else {
    final base = s.intervalDays < 1 ? 1 : s.intervalDays;
    days = switch (grade) {
      ReviewGrade.hard => (base * 1.2).round(),
      ReviewGrade.easy => (base * ease * 1.3).round(),
      _ => (base * ease).round(),
    };
    if (days <= base) days = base + 1;
  }
  if (days > 365) days = 365;

  final day = DateTime(now.year, now.month, now.day);
  return ReviewOutcome(
    ReviewState(
      ease: ease,
      intervalDays: days,
      reps: s.reps + 1,
      lapses: s.lapses,
    ),
    DateTime(day.year, day.month, day.day + days),
  );
}

double _clamp(double e) =>
    e < kMinEase ? kMinEase : (e > kMaxEase ? kMaxEase : e);

/// „za 10 min", „zítra", „za 3 dny" — what the grade button promises.
String describeNextReview(ReviewOutcome o, DateTime now) {
  final diff = o.dueAt.difference(now);
  if (diff.inHours < 1) {
    return 'za ${(diff.inSeconds / 60).round().clamp(1, 59)} min';
  }
  final days = o.state.intervalDays;
  if (days <= 1) return 'zítra';
  if (days < 5) return 'za $days dny';
  if (days < 30) return 'za $days dní';
  final months = (days / 30).round();
  if (months <= 1) return 'za měsíc';
  if (months < 5) return 'za $months měsíce';
  return 'za $months měsíců';
}
