import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/web_answer_service.dart';

void main() {
  group('webRetryAfter', () {
    test('reads the wait Groq writes into the message', () {
      expect(
        webRetryAfter(
          'Rate limit reached for model `openai/gpt-oss-120b` in organization '
          '`org_01` service tier `on_demand` on tokens per minute (TPM): '
          'Limit 8000, Used 1335, Requested 7915. Please try again in 9.375s. '
          'Need more tokens? Upgrade to Dev Tier today.',
        ),
        const Duration(milliseconds: 9375),
      );
    });

    test('rounds up, so the retry never lands before the limit resets', () {
      expect(webRetryAfter('try again in 0.0001s'),
          const Duration(milliseconds: 1));
    });

    test('reads a whole number of seconds', () {
      expect(webRetryAfter('Please try again in 48s.'),
          const Duration(seconds: 48));
    });

    // A limit that resets every minute makes five seconds the right guess, and
    // the caller's budget bounds it either way.
    test('falls back to five seconds when the message says nothing useful', () {
      expect(webRetryAfter('Rate limit reached.'), const Duration(seconds: 5));
      expect(webRetryAfter(''), const Duration(seconds: 5));
      expect(webRetryAfter('try again in a moment'), const Duration(seconds: 5));
    });
  });
}
