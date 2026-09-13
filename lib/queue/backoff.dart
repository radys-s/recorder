import 'dart:math' as math;

/// Delay before retry number [attempt] (1 = the first retry after the initial
/// failure).
///
/// Exponential with a cap, plus jitter. The jitter matters more than usual
/// here: a network outage during a meeting fails every queued chunk at once,
/// and without it the whole backlog would retry in lockstep and hit Groq's
/// rate limiter as one burst every time.
///
/// [random] is injectable so tests can pin the jitter.
Duration retryDelay(
  int attempt, {
  Duration base = const Duration(seconds: 5),
  Duration cap = const Duration(minutes: 10),
  double jitterFraction = 0.25,
  math.Random? random,
}) {
  if (attempt < 1) return Duration.zero;

  // Cap the exponent before computing the power: a long outage would otherwise
  // overflow into a nonsense delay long before the cap could clamp it.
  const maxExponent = 20;
  final exponent = math.min(attempt - 1, maxExponent);
  final rawMs = base.inMilliseconds * math.pow(2, exponent).toInt();
  final cappedMs = math.min(rawMs, cap.inMilliseconds);

  // Jitter is symmetric around the delay, so the average backoff still follows
  // the intended curve.
  final rng = random ?? math.Random();
  final spread = (cappedMs * jitterFraction).round();
  final offset = spread == 0 ? 0 : rng.nextInt(spread * 2 + 1) - spread;

  return Duration(milliseconds: math.max(0, cappedMs + offset));
}

/// After this many failed attempts a queue row stops being retried and is
/// parked as permanently failed, so a chunk that is somehow always rejected
/// can't retry forever.
const int kMaxRetryAttempts = 8;
