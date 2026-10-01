import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/features/meeting_detail/widgets/transcription_wait_notice.dart';
import 'package:recorder/queue/transcription_wait.dart';

void main() {
  test('a limit names the time it ends', () {
    expect(
      transcriptionWaitText(
        TranscriptionWait.rateLimit(DateTime(2026, 10, 1, 10, 42)),
      ),
      'Přepis čeká na limit, pokračuje v 10:42',
    );
    expect(
      transcriptionWaitText(
        TranscriptionWait.rateLimit(DateTime(2026, 10, 1, 9, 5)),
      ),
      'Přepis čeká na limit, pokračuje v 9:05',
    );
  });

  test('a missing key says where to put it', () {
    expect(
      transcriptionWaitText(const TranscriptionWait.missingKey()),
      'Chybí klíč pro přepis — ulož ho v Nastavení',
    );
  });

  test('waits compare by kind and end', () {
    final at = DateTime(2026, 10, 1, 10);
    expect(TranscriptionWait.rateLimit(at), TranscriptionWait.rateLimit(at));
    expect(
      TranscriptionWait.rateLimit(at) ==
          TranscriptionWait.rateLimit(at.add(const Duration(seconds: 1))),
      isFalse,
    );
    expect(
      const TranscriptionWait.missingKey(),
      const TranscriptionWait.missingKey(),
    );
  });

  group('TranscriptionWaitNotice', () {
    Future<void> pump(WidgetTester tester, TranscriptionWait? wait) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              transcriptionWaitProvider.overrideWith(
                (ref) => Stream.value(wait),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: TranscriptionWaitNotice()),
            ),
          ),
        );

    testWidgets('shows why chunks wait', (tester) async {
      await pump(
        tester,
        TranscriptionWait.rateLimit(DateTime(2026, 10, 1, 10, 42)),
      );
      await tester.pump();
      expect(find.text('Přepis čeká na limit, pokračuje v 10:42'), findsOne);
    });

    testWidgets('shows nothing while transcription works', (tester) async {
      await pump(tester, null);
      await tester.pump();
      expect(find.byType(Text), findsNothing);
    });
  });
}
