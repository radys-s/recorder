import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/learning/scheduler.dart';

void main() {
  final now = DateTime(2026, 9, 28, 14, 30);

  test('a new card graded Dobře is due tomorrow at midnight', () {
    final o = schedule(const ReviewState(), ReviewGrade.good, now);
    expect(o.state.reps, 1);
    expect(o.state.intervalDays, 1);
    expect(o.dueAt, DateTime(2026, 9, 29));
    expect(o.state.ease, 2.5);
  });

  test('Snadno skips ahead and raises the ease, Těžké lowers it', () {
    final easy = schedule(const ReviewState(), ReviewGrade.easy, now);
    expect(easy.state.intervalDays, 3);
    expect(easy.state.ease, closeTo(2.65, 1e-9));
    final hard = schedule(const ReviewState(), ReviewGrade.hard, now);
    expect(hard.state.intervalDays, 1);
    expect(hard.state.ease, closeTo(2.35, 1e-9));
  });

  test('the second review gives three days, then the interval × ease', () {
    final second = schedule(
      const ReviewState(reps: 1, intervalDays: 1),
      ReviewGrade.good,
      now,
    );
    expect(second.state.intervalDays, 3);
    final third = schedule(second.state, ReviewGrade.good, now);
    expect(third.state.intervalDays, 8); // 3 × 2.5 rounded
    expect(third.dueAt, DateTime(2026, 10, 6));
  });

  test('Znovu resets the streak, counts a lapse and comes back in 10 min', () {
    final o = schedule(
      const ReviewState(reps: 3, intervalDays: 8, lapses: 1),
      ReviewGrade.again,
      now,
    );
    expect(o.state.reps, 0);
    expect(o.state.intervalDays, 0);
    expect(o.state.lapses, 2);
    expect(o.dueAt, now.add(kRelearnDelay));
    // A card never learned is not a lapse.
    expect(
      schedule(const ReviewState(), ReviewGrade.again, now).state.lapses,
      0,
    );
  });

  test('ease stays between its bounds and intervals are capped', () {
    var s = const ReviewState(ease: 1.35);
    s = schedule(s, ReviewGrade.again, now).state;
    expect(s.ease, kMinEase);
    final long = schedule(
      const ReviewState(reps: 5, intervalDays: 300, ease: 2.9),
      ReviewGrade.easy,
      now,
    );
    expect(long.state.intervalDays, 365);
    expect(long.state.ease, kMaxEase);
  });

  test('Těžké on a long interval still moves it forward', () {
    final o = schedule(
      const ReviewState(reps: 4, intervalDays: 2, ease: 1.3),
      ReviewGrade.hard,
      now,
    );
    expect(o.state.intervalDays, greaterThan(2));
  });

  test('the grade buttons describe when the card comes back', () {
    String d(ReviewState s, ReviewGrade g) =>
        describeNextReview(schedule(s, g, now), now);
    expect(d(const ReviewState(), ReviewGrade.again), 'za 10 min');
    expect(d(const ReviewState(), ReviewGrade.good), 'zítra');
    expect(d(const ReviewState(), ReviewGrade.easy), 'za 3 dny');
    expect(
      d(const ReviewState(reps: 3, intervalDays: 10), ReviewGrade.good),
      'za 25 dní',
    );
    expect(
      d(const ReviewState(reps: 3, intervalDays: 40), ReviewGrade.good),
      'za 3 měsíce',
    );
  });
}
