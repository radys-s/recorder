import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/preferences_dao.dart';
import 'package:recorder/data/db/daos/transcript_segments_dao.dart';
import 'package:recorder/data/db/daos/upload_queue_dao.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';
import 'package:recorder/data/db/tables/upload_queue_table.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/queue/transcription_queue_worker.dart';
import 'package:recorder/stt/lesson_vocabulary.dart';
import 'package:recorder/stt/stt_provider.dart';
import 'package:recorder/stt/transcript_corrector.dart';

/// An in-memory queue table with the same due-row rule as the real DAO.
class _Queue implements UploadQueueDao {
  final rows = <UploadQueueData>[];
  final outstanding = StreamController<int>.broadcast();
  var backoffClears = 0;

  UploadQueueData byId(int id) => rows.firstWhere((r) => r.id == id);

  void _change(int id, UploadQueueData Function(UploadQueueData row) change) {
    final i = rows.indexWhere((r) => r.id == id);
    rows[i] = change(rows[i]);
  }

  @override
  Future<List<UploadQueueData>> dueRows(DateTime now) async => [
    for (final r in rows)
      if (r.status == QueueStatus.pending ||
          (r.status == QueueStatus.failedRetryable &&
              r.nextRetryAt != null &&
              !r.nextRetryAt!.isAfter(now)))
        r,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Stream<int> watchOutstandingCount() => outstanding.stream;

  @override
  Future<int> resetStuckUploads() async {
    var count = 0;
    for (final r in [...rows]) {
      if (r.status == QueueStatus.uploading) {
        _change(r.id, (x) => x.copyWith(status: QueueStatus.pending));
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> clearRetryBackoff() async {
    backoffClears++;
    var count = 0;
    for (final r in [...rows]) {
      if (r.status == QueueStatus.failedRetryable) {
        _change(r.id, (x) => x.copyWith(nextRetryAt: Value(DateTime.now())));
        count++;
      }
    }
    return count;
  }

  @override
  Future<void> markUploading(int id) async =>
      _change(id, (x) => x.copyWith(status: QueueStatus.uploading));

  @override
  Future<void> markSucceeded(int id) async =>
      _change(id, (x) => x.copyWith(status: QueueStatus.succeeded));

  @override
  Future<void> markFailedRetryable(
    int id,
    int attemptCount,
    DateTime nextRetryAt,
    String error,
  ) async => _change(
    id,
    (x) => x.copyWith(
      status: QueueStatus.failedRetryable,
      attemptCount: attemptCount,
      nextRetryAt: Value(nextRetryAt),
      lastError: Value(error),
    ),
  );

  @override
  Future<void> markFailedPermanent(int id, String error) async => _change(
    id,
    (x) => x.copyWith(
      status: QueueStatus.failedPermanent,
      lastError: Value(error),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Segments implements TranscriptSegmentsDao {
  final byId = <int, TranscriptSegment>{};
  final statusLog = <int, List<SegmentStatus>>{};

  @override
  Future<TranscriptSegment?> segmentById(int id) async => byId[id];

  @override
  Future<String?> previousTranscript(int meetingId, int sequence) async {
    final earlier = [
      for (final s in byId.values)
        if (s.meetingId == meetingId &&
            s.sequence < sequence &&
            s.content != null)
          s,
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));
    return earlier.isEmpty ? null : earlier.last.content;
  }

  @override
  Future<void> updateSegmentText(
    int id,
    String text,
    SegmentStatus status, {
    double? confidence,
    String? rawContent,
  }) async {
    byId[id] = byId[id]!.copyWith(
      content: Value(text),
      status: status,
      confidence: Value(confidence),
      rawContent: rawContent == null ? const Value.absent() : Value(rawContent),
    );
    (statusLog[id] ??= []).add(status);
  }

  @override
  Future<void> correctSegment(int id, String text) async {
    final row = byId[id]!;
    byId[id] = row.copyWith(
      content: Value(text),
      rawContent: Value(row.rawContent ?? row.content),
    );
  }

  @override
  Future<void> updateSegmentStatus(int id, SegmentStatus status) async {
    byId[id] = byId[id]!.copyWith(status: status);
    (statusLog[id] ??= []).add(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Prefs implements PreferencesDao {
  _Prefs(this.language, this.sensitivity);
  final TranscriptLanguage language;
  final MicSensitivity sensitivity;

  @override
  Future<Preference> current() async => Preference(
    id: 0,
    transcriptLanguage: language,
    notesDepth: NotesDepth.standard,
    accentPreset: AccentPreset.gold,
    liveAnswersEnabled: true,
    webAnswersEnabled: false,
    micSensitivity: sensitivity,
    onboardingDismissed: false,
    contextCorrection: true,
    audioRetention: AudioRetention.sevenDays,
    lessonReminder: LessonReminder.off,
    driveSyncEnabled: false,
    driveIncludeTranscripts: false,
    termsAcceptedVersion: 1,
    recordingNoticeDismissed: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _SttCall = ({
  String path,
  String? prompt,
  String? language,
  MicSensitivity sensitivity,
});

class _Stt implements SttProvider {
  _Stt(this.respond);

  /// Called with the audio path; may throw, may hang on a completer.
  final FutureOr<TranscriptionResult> Function(String path) respond;
  final calls = <_SttCall>[];
  final glossaries = <String?>[];

  @override
  Future<TranscriptionResult> transcribe({
    required File audioFile,
    String? promptContext,
    String? languageCode,
    MicSensitivity sensitivity = MicSensitivity.medium,
    String? glossary,
  }) async {
    glossaries.add(glossary);
    calls.add((
      path: audioFile.path,
      prompt: promptContext,
      language: languageCode,
      sensitivity: sensitivity,
    ));
    return respond(audioFile.path);
  }
}

class _Connectivity implements Connectivity {
  final changes = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers the corrector with a fixed text, or fails.
class _Llm extends LlmProvider {
  _Llm(this.text, {this.throwing = false});
  final String? text;
  final bool throwing;

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    if (throwing) throw const AiTransientException('rate limited');
    return LlmCompletion(content: text == null ? '{}' : '{"texts": ["$text"]}');
  }
}

/// Absolute, so `resolveStoredPath` never asks the platform for a directory.
String _path(int sequence) =>
    '${Directory.systemTemp.path}${Platform.pathSeparator}chunk_$sequence.wav';

class _World {
  _World(
    FutureOr<TranscriptionResult> Function(String path) respond, {
    TranscriptLanguage language = TranscriptLanguage.czech,
    MicSensitivity sensitivity = MicSensitivity.medium,
    void Function(TranscriptSegment segment, String text)? onTranscribed,
    Future<LessonListening?> Function(int meetingId)? listeningFor,
    TranscriptCorrector? corrector,
    Future<void> Function(Set<int> termIds)? onTermsUsed,
  }) : stt = _Stt(respond) {
    worker = TranscriptionQueueWorker(
      queue,
      segments,
      _Prefs(language, sensitivity),
      stt,
      connectivity: connectivity,
      onTranscribed: onTranscribed,
      listeningFor: listeningFor,
      corrector: corrector,
      onTermsUsed: onTermsUsed,
      // Only the events under test wake the worker, never the clock.
      tick: const Duration(hours: 1),
    );
  }

  final queue = _Queue();
  final segments = _Segments();
  final connectivity = _Connectivity();
  final _Stt stt;
  late final TranscriptionQueueWorker worker;

  int segmentId(int sequence) => 10 + sequence;
  int rowId(int sequence) => 1 + sequence;

  void addSegment(int sequence, {String? content}) {
    segments.byId[segmentId(sequence)] = TranscriptSegment(
      id: segmentId(sequence),
      meetingId: 3,
      sequence: sequence,
      startMs: sequence * 8000,
      endMs: (sequence + 1) * 8000,
      content: content,
      status: content == null
          ? SegmentStatus.pending
          : SegmentStatus.transcribed,
      localAudioPath: _path(sequence),
      createdAt: DateTime(2026, 9, 14, 9, 0, sequence),
    );
  }

  void enqueue(
    int sequence, {
    QueueStatus status = QueueStatus.pending,
    int attemptCount = 0,
    DateTime? nextRetryAt,
  }) {
    addSegment(sequence);
    queue.rows.add(
      UploadQueueData(
        id: rowId(sequence),
        segmentId: segmentId(sequence),
        meetingId: 3,
        localFilePath: _path(sequence),
        status: status,
        attemptCount: attemptCount,
        nextRetryAt: nextRetryAt,
        createdAt: DateTime(2026, 9, 14, 9, 0, sequence),
        updatedAt: DateTime(2026, 9, 14, 9, 0, sequence),
      ),
    );
  }

  UploadQueueData row(int sequence) => queue.byId(rowId(sequence));
  TranscriptSegment segment(int sequence) =>
      segments.byId[segmentId(sequence)]!;
}

TranscriptionResult _text(String text) => TranscriptionResult(text: text);

/// Everything here is in-memory futures, so a handful of event-loop turns is
/// plenty; `poke()` cannot be awaited for this because it returns at once
/// while a drain is already running.
Future<void> _until(bool Function() done, {String what = 'condition'}) async {
  for (var i = 0; i < 500; i++) {
    if (done()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for $what');
}

Future<void> _settle() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'transcribes a row with the context and settings of the moment',
    () async {
      final transcribed = <(int, String)>[];
      final world = _World(
        (_) => _text('  A tady pokračujeme dál.  '),
        language: TranscriptLanguage.english,
        sensitivity: MicSensitivity.high,
        onTranscribed: (s, text) => transcribed.add((s.id, text)),
      );
      world.addSegment(0, content: 'Předchozí věta.');
      world.enqueue(1);

      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.succeeded);
      await world.worker.stop();

      final call = world.stt.calls.single;
      expect(call.path, _path(1));
      expect(call.prompt, 'Předchozí věta.');
      expect(call.language, 'en');
      expect(call.sensitivity, MicSensitivity.high);

      expect(world.segment(1).content, 'A tady pokračujeme dál.');
      expect(world.segment(1).status, SegmentStatus.transcribed);
      expect(world.segments.statusLog[world.segmentId(1)], [
        SegmentStatus.uploading,
        SegmentStatus.transcribed,
      ]);
      expect(transcribed, [(world.segmentId(1), 'A tady pokračujeme dál.')]);
    },
  );

  test(
    'the lesson glossary goes to Whisper with the meeting it belongs to',
    () async {
      final asked = <int>[];
      final world = _World(
        (_) => _text('Babička jde s dětmi na procházku.'),
        listeningFor: (meetingId) async {
          asked.add(meetingId);
          return const LessonListening(leadIn: 'Babička, Viktorka, Proško');
        },
      );
      world.enqueue(1);
      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.succeeded);
      await world.worker.stop();

      expect(asked, [3]);
      expect(world.stt.glossaries.single, 'Babička, Viktorka, Proško');
      expect(world.segment(1).content, 'Babička jde s dětmi na procházku.');
    },
  );

  test('a failing glossary lookup still transcribes', () async {
    final world = _World(
      (_) => _text('Dobrý den.'),
      listeningFor: (_) async => throw StateError('db closed'),
    );
    world.enqueue(1);
    await world.worker.start();
    await _until(() => world.row(1).status == QueueStatus.succeeded);
    await world.worker.stop();
    expect(world.stt.glossaries.single, isNull);
    expect(world.segment(1).content, 'Dobrý den.');
  });

  group('listening to the lesson', () {
    const lesson = LessonListening(
      subjectName: 'Čeština',
      leadIn: 'Hodina: Čeština.',
      corrections: [(heard: 'prosko', term: 'Proško')],
      correctionIds: [7],
      terms: [(term: 'Proško', id: 7), (term: 'Viktorka', id: 8)],
    );

    Future<(_World, List<String>, Set<int>)> run(
      TranscriptionResult result, {
      String? corrected,
      bool throwing = false,
    }) async {
      final transcribed = <String>[];
      final used = <int>{};
      final llm = _Llm(corrected, throwing: throwing);
      final world = _World(
        (_) => result,
        onTranscribed: (_, text) => transcribed.add(text),
        listeningFor: (_) async => lesson,
        corrector: TranscriptCorrector(llm),
        onTermsUsed: (ids) async => used.addAll(ids),
      );
      world.enqueue(1);
      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.succeeded);
      await world.worker.settle();
      await world.worker.stop();
      return (world, transcribed, used);
    }

    test(
      'a word the student fixed before is fixed again, original kept',
      () async {
        final (world, transcribed, used) = await run(
          const TranscriptionResult(text: 'Pak přišel prosko k mlýnu.'),
        );
        expect(world.segment(1).content, 'Pak přišel Proško k mlýnu.');
        expect(world.segment(1).rawContent, 'Pak přišel prosko k mlýnu.');
        expect(transcribed, ['Pak přišel Proško k mlýnu.']);
        expect(used, {7});
      },
    );

    test('an accepted AI correction replaces the stored text, and the answer '
        'did not wait for it', () async {
      final (world, transcribed, used) = await run(
        const TranscriptionResult(text: 'A viktorko zpívala u vody.'),
        corrected: 'A Viktorka zpívala u vody.',
      );
      expect(world.segment(1).content, 'A Viktorka zpívala u vody.');
      expect(world.segment(1).rawContent, 'A viktorko zpívala u vody.');
      // The answer ran on what Whisper heard plus the deterministic fixes;
      // the AI pass is a batch that lands later and only rewrites the row.
      expect(transcribed, ['A viktorko zpívala u vody.']);
      expect(used, {8});
    });

    test('a rewrite is rejected and the heard text stands', () async {
      final (world, transcribed, _) = await run(
        const TranscriptionResult(text: 'A viktorko zpívala u vody.'),
        corrected: 'Viktorka byla postava, která ráda zpívala u potoka.',
      );
      expect(world.segment(1).content, 'A viktorko zpívala u vody.');
      expect(world.segment(1).rawContent, isNull);
      expect(transcribed, ['A viktorko zpívala u vody.']);
    });

    test('a failing corrector never costs the transcript', () async {
      final (world, transcribed, _) = await run(
        const TranscriptionResult(text: 'A viktorko zpívala u vody.'),
        throwing: true,
      );
      expect(world.segment(1).content, 'A viktorko zpívala u vody.');
      expect(transcribed, hasLength(1));
    });

    test(
      'confidence is stored, and a very doubtful chunk is not answered',
      () async {
        final (world, transcribed, _) = await run(
          const TranscriptionResult(
            text: 'něco jako by říkala',
            confidence: -1.6,
          ),
        );
        expect(world.segment(1).confidence, -1.6);
        expect(world.segment(1).content, 'něco jako by říkala');
        expect(transcribed, isEmpty);
      },
    );
  });

  group('text that nobody said', () {
    Future<(_World, List<String>)> run(
      String sttText, {
      String? previous,
      String? glossary,
    }) async {
      final transcribed = <String>[];
      final world = _World(
        (_) => _text(sttText),
        onTranscribed: (_, text) => transcribed.add(text),
        listeningFor: glossary == null
            ? null
            : (_) async => LessonListening(leadIn: glossary),
      );
      if (previous != null) world.addSegment(0, content: previous);
      world.enqueue(1);
      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.succeeded);
      await world.worker.settle();
      await world.worker.stop();
      return (world, transcribed);
    }

    test(
      'a whole subtitle credit leaves the segment empty and silent',
      () async {
        final (world, transcribed) = await run('Titulky vytvořil Jan Novák');
        expect(world.segment(1).content, isNull);
        expect(world.segment(1).status, SegmentStatus.transcribed);
        expect(transcribed, isEmpty);
      },
    );

    test(
      'a trailing sign-off is cut, and the rest goes on to live answers',
      () async {
        final (world, transcribed) = await run(
          'Tak to je všechno. Děkuji za pozornost.',
        );
        expect(world.segment(1).content, 'Tak to je všechno.');
        expect(transcribed, ['Tak to je všechno.']);
      },
    );

    test('an echo of the glossary is dropped', () async {
      final (world, transcribed) = await run(
        'Babička, Viktorka, Proško.',
        glossary: 'Babička, Viktorka, Proško, Božena Němcová',
      );
      expect(world.segment(1).content, isNull);
      expect(transcribed, isEmpty);
    });

    test('an echo of the previous chunk is dropped', () async {
      final (world, transcribed) = await run(
        'zhruba čtyřicet procent rozpočtu',
        previous: 'Zatím jsme vyčerpali zhruba čtyřicet procent rozpočtu.',
      );
      expect(world.segment(1).content, isNull);
      expect(transcribed, isEmpty);
    });
  });

  group('failures', () {
    test('a transient one goes back in line with a backoff', () async {
      final world = _World(
        (_) =>
            throw const SttTransientException('bad gateway', statusCode: 503),
      );
      world.enqueue(1);
      final before = DateTime.now();

      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.failedRetryable);
      await _settle();
      await world.worker.stop();

      final row = world.row(1);
      expect(row.attemptCount, 1);
      expect(row.nextRetryAt!.isAfter(before), isTrue);
      expect(row.lastError, 'bad gateway');
      expect(world.stt.calls, hasLength(1), reason: 'no spin on a backoff');
      expect(world.segment(1).status, SegmentStatus.pending);
    });

    test('the last allowed attempt parks the row', () async {
      final world = _World((_) => throw const SttTransientException('timeout'));
      world.enqueue(
        1,
        status: QueueStatus.failedRetryable,
        attemptCount: 7,
        nextRetryAt: DateTime(2026, 1, 1),
      );

      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.failedPermanent);
      await world.worker.stop();

      expect(world.row(1).lastError, startsWith('gave up after 8 attempts'));
      expect(world.segment(1).status, SegmentStatus.failed);
    });

    test('a permanent one parks the row at once', () async {
      final world = _World(
        (_) => throw const SttPermanentException('bad key', statusCode: 401),
      );
      world.enqueue(1);

      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.failedPermanent);
      await _settle();
      await world.worker.stop();

      expect(world.row(1).attemptCount, 0);
      expect(world.row(1).lastError, 'bad key');
      expect(world.segment(1).status, SegmentStatus.failed);
      expect(world.stt.calls, hasLength(1));
    });

    test('an unclassified error is retried, not fatal', () async {
      final world = _World((_) => throw StateError('disk full'));
      world.enqueue(1);

      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.failedRetryable);
      await world.worker.stop();

      expect(world.row(1).attemptCount, 1);
      expect(world.row(1).lastError, contains('disk full'));
    });

    test('a callback that throws does not stop the next row', () async {
      final world = _World(
        (path) => _text(path == _path(1) ? 'První věta.' : 'Druhá věta.'),
        onTranscribed: (_, _) => throw StateError('answer service broke'),
      );
      world.enqueue(1);
      world.enqueue(2);

      await world.worker.start();
      await _until(() => world.row(2).status == QueueStatus.succeeded);
      await world.worker.stop();

      expect(world.row(1).status, QueueStatus.succeeded);
      expect(world.stt.calls.map((c) => c.path), [_path(1), _path(2)]);
      // Serial and in order, so the second chunk sees the first one's text.
      expect(world.stt.calls.last.prompt, 'První věta.');
    });
  });

  group('waking up', () {
    test('a row stranded as uploading by a killed run is picked up', () async {
      final world = _World((_) => _text('Ahoj.'));
      world.enqueue(1, status: QueueStatus.uploading);

      await world.worker.start();
      await _until(() => world.row(1).status == QueueStatus.succeeded);
      await world.worker.stop();
    });

    test('a write to the queue wakes an idle worker', () async {
      final world = _World((_) => _text('Ahoj.'));
      await world.worker.start();
      await _settle();

      world.enqueue(1);
      world.queue.outstanding.add(1);
      await _until(() => world.row(1).status == QueueStatus.succeeded);
      await world.worker.stop();
    });

    test('only a real reconnect cuts a backoff short', () async {
      final world = _World((_) => _text('Ahoj.'));
      world.enqueue(
        1,
        status: QueueStatus.failedRetryable,
        attemptCount: 2,
        nextRetryAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await world.worker.start();
      await _settle();
      expect(world.stt.calls, isEmpty);

      // The first event reports the current state; it is not a recovery.
      world.connectivity.changes.add([ConnectivityResult.wifi]);
      await _settle();
      expect(world.queue.backoffClears, 0);
      expect(world.stt.calls, isEmpty);

      world.connectivity.changes.add([ConnectivityResult.none]);
      await _settle();
      world.connectivity.changes.add([ConnectivityResult.mobile]);
      await _until(() => world.row(1).status == QueueStatus.succeeded);
      await world.worker.stop();

      expect(world.queue.backoffClears, 1);
      expect(world.row(1).attemptCount, 2, reason: 'the budget is not reset');
    });

    test('after stop nothing wakes it', () async {
      final world = _World((_) => _text('Ahoj.'));
      await world.worker.start();
      await world.worker.stop();

      world.enqueue(1);
      world.queue.outstanding.add(1);
      world.connectivity.changes.add([ConnectivityResult.none]);
      world.connectivity.changes.add([ConnectivityResult.wifi]);
      await world.worker.poke();
      await _settle();

      expect(world.stt.calls, isEmpty);
      expect(world.row(1).status, QueueStatus.pending);
    });

    test('stop lets the upload in flight finish but starts no other', () async {
      final gate = Completer<TranscriptionResult>();
      final world = _World((_) => gate.future);
      world.enqueue(1);
      world.enqueue(2);

      await world.worker.start();
      await _until(() => world.stt.calls.isNotEmpty);
      await world.worker.stop();
      gate.complete(_text('Ahoj.'));
      await _settle();

      expect(world.row(1).status, QueueStatus.succeeded);
      expect(world.row(2).status, QueueStatus.pending);
      expect(world.stt.calls, hasLength(1));
    });
  });
}
