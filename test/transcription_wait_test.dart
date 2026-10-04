import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/features/meeting_detail/widgets/transcription_wait_notice.dart';
import 'package:recorder/queue/transcription_wait.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/features/meeting_detail/meeting_detail_providers.dart';

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
    TranscriptSegment segment(SegmentStatus status) => TranscriptSegment(
      id: 1,
      meetingId: 1,
      sequence: 0,
      startMs: 0,
      endMs: 1000,
      status: status,
      localAudioPath: 'synthetic.wav',
      createdAt: DateTime(2026),
    );
    testWidgets('a global limit does not label an already processed lesson', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transcriptionWaitProvider.overrideWith(
              (ref) => Stream.value(const TranscriptionWait.missingKey()),
            ),
            meetingSegmentsProvider(1).overrideWith(
              (ref) => Stream.value([segment(SegmentStatus.transcribed)]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TranscriptionWaitNotice(meetingId: 1)),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Chybí klíč'), findsNothing);
    });
    testWidgets(
      'a pending lesson has an actionable notice at large text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              transcriptionWaitProvider.overrideWith(
                (ref) => Stream.value(const TranscriptionWait.missingKey()),
              ),
              meetingSegmentsProvider(1).overrideWith(
                (ref) => Stream.value([segment(SegmentStatus.pending)]),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              ),
              home: const Scaffold(body: TranscriptionWaitNotice(meetingId: 1)),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Otevřít nastavení'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
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
