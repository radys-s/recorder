import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/listening_diagnostics.dart';

void main() {
  test('keeps a bounded, privacy-safe chronological trace in debug mode', () {
    final diagnostics = ListeningDiagnostics(capacity: 2, enabled: true);
    diagnostics.record(
      ListeningStage.chunk,
      ListeningOutcome.progress,
      'closed_silence',
      meetingId: 7,
      sequence: 2,
      metrics: const {'duration_ms': 8100},
    );
    diagnostics.record(
      ListeningStage.transcription,
      ListeningOutcome.accepted,
      'transcript_written',
      segmentId: 42,
    );
    diagnostics.record(
      ListeningStage.decision,
      ListeningOutcome.rejected,
      'off_topic',
    );

    expect(diagnostics.events.value, hasLength(2));
    expect(diagnostics.events.value.first.reason, 'transcript_written');
    expect(diagnostics.events.value.last.line, contains('reason=off_topic'));
    expect(diagnostics.events.value.last.line, isNot(contains('transcript=')));
    diagnostics.dispose();
  });
}
