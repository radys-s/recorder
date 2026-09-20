import 'package:flutter/foundation.dart';

import 'logging.dart';

/// A privacy-safe breadcrumb for one pass through live listening.
///
/// It deliberately records ids, state and small numeric metadata only. Audio,
/// transcript text and API responses stay out of this trail, so turning on the
/// debug screen cannot turn a classroom recording into a second data store.
enum ListeningStage {
  capture,
  chunk,
  transcription,
  candidate,
  decision,
  card,
  presentation,
}

enum ListeningOutcome { progress, accepted, rejected, failed }

class ListeningDiagnostic {
  const ListeningDiagnostic({
    required this.at,
    required this.stage,
    required this.outcome,
    required this.reason,
    this.meetingId,
    this.sequence,
    this.segmentId,
    this.queueId,
    this.metrics = const {},
  });

  final DateTime at;
  final ListeningStage stage;
  final ListeningOutcome outcome;
  final String reason;
  final int? meetingId;
  final int? sequence;
  final int? segmentId;
  final int? queueId;
  final Map<String, Object?> metrics;

  String get line {
    final fields = <String>[
      'stage=${stage.name}',
      'outcome=${outcome.name}',
      'reason=$reason',
      if (meetingId != null) 'meeting=$meetingId',
      if (sequence != null) 'seq=$sequence',
      if (segmentId != null) 'segment=$segmentId',
      if (queueId != null) 'queue=$queueId',
      ...metrics.entries.map((entry) => '${entry.key}=${entry.value}'),
    ];
    return fields.join(' ');
  }
}

/// Bounded in-memory diagnostics for the listening pipeline.
///
/// Production still writes the terse, greppable [AppLog] line. The in-memory
/// trail only exists in debug builds (or an explicitly enabled test), so no
/// user-visible data and no unbounded history are added to a release build.
class ListeningDiagnostics {
  ListeningDiagnostics({this.capacity = 300, bool? enabled})
    : _enabled = enabled ?? kDebugMode;

  final int capacity;
  final bool _enabled;
  final ValueNotifier<List<ListeningDiagnostic>> events =
      ValueNotifier<List<ListeningDiagnostic>>(const []);

  void record(
    ListeningStage stage,
    ListeningOutcome outcome,
    String reason, {
    int? meetingId,
    int? sequence,
    int? segmentId,
    int? queueId,
    Map<String, Object?> metrics = const {},
  }) {
    final event = ListeningDiagnostic(
      at: DateTime.now(),
      stage: stage,
      outcome: outcome,
      reason: reason,
      meetingId: meetingId,
      sequence: sequence,
      segmentId: segmentId,
      queueId: queueId,
      metrics: Map.unmodifiable(metrics),
    );
    AppLog.d('listening.trace', event.line);
    if (!_enabled) return;
    final next = [...events.value, event];
    if (next.length > capacity) next.removeRange(0, next.length - capacity);
    events.value = List.unmodifiable(next);
  }

  void clear() => events.value = const [];

  void dispose() => events.dispose();
}
