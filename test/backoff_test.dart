import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/queue/backoff.dart';

/// Returns the midpoint of the jitter window, i.e. the undisturbed curve.
Duration _noJitter(int attempt, {Duration? cap}) => retryDelay(
      attempt,
      jitterFraction: 0,
      cap: cap ?? const Duration(minutes: 10),
    );

void main() {
  test('doubles from the base delay', () {
    expect(_noJitter(1), const Duration(seconds: 5));
    expect(_noJitter(2), const Duration(seconds: 10));
    expect(_noJitter(3), const Duration(seconds: 20));
    expect(_noJitter(4), const Duration(seconds: 40));
  });

  test('clamps at the cap instead of growing forever', () {
    expect(_noJitter(8), const Duration(minutes: 10));
    expect(_noJitter(20), const Duration(minutes: 10));
    // The exponent is clamped too, so a very long outage cannot overflow.
    expect(_noJitter(100000), const Duration(minutes: 10));
  });

  test('an attempt below 1 has no delay', () {
    expect(retryDelay(0), Duration.zero);
    expect(retryDelay(-3), Duration.zero);
  });

  test('jitter stays inside the requested fraction of the delay', () {
    final rng = math.Random(1234);
    for (var attempt = 1; attempt <= 6; attempt++) {
      final centre = _noJitter(attempt).inMilliseconds;
      final low = (centre * 0.75).round();
      final high = (centre * 1.25).round();

      for (var i = 0; i < 200; i++) {
        final ms = retryDelay(attempt, random: rng).inMilliseconds;
        expect(ms, inInclusiveRange(low, high));
      }
    }
  });

  test('jitter actually spreads simultaneous failures apart', () {
    final rng = math.Random(7);
    // Simulates 50 chunks failing at the same instant during an outage.
    final delays = {
      for (var i = 0; i < 50; i++) retryDelay(3, random: rng).inMilliseconds,
    };
    expect(
      delays.length,
      greaterThan(20),
      reason: 'without jitter all 50 would share one delay',
    );
  });

  test('never returns a negative delay', () {
    final rng = math.Random(99);
    for (var i = 0; i < 500; i++) {
      expect(
        retryDelay(1, jitterFraction: 2.0, random: rng),
        greaterThanOrEqualTo(Duration.zero),
      );
    }
  });
}
