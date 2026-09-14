import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/llm_provider.dart';
import 'package:recorder/ai/notes_generator.dart';
import 'package:recorder/core/constants.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/daos/meeting_notes_dao.dart';
import 'package:recorder/data/db/daos/transcript_segments_dao.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/db/tables/transcript_segments_table.dart';

class _Notes implements MeetingNotesDao {
  _Notes({this.failGenerating = false, this.failFailing = false});
  final bool failGenerating;
  final bool failFailing;
  final events = <String>[];
  NotesDepth? depth;
  String? model;
  String? content;
  String? error;

  @override
  Future<void> markGenerating(int meetingId, NotesDepth d, String m) async {
    if (failGenerating) throw StateError('db locked');
    events.add('generating');
    depth = d;
    model = m;
  }

  @override
  Future<void> markReady(int meetingId, String c) async {
    events.add('ready');
    content = c;
  }

  @override
  Future<void> markFailed(int meetingId, String e) async {
    if (failFailing) throw StateError('db locked');
    events.add('failed');
    error = e;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Segments implements TranscriptSegmentsDao {
  _Segments(this.contents);
  final List<String?> contents;

  @override
  Future<List<TranscriptSegment>> segmentsForMeeting(int meetingId) async => [
        for (var i = 0; i < contents.length; i++)
          TranscriptSegment(
            id: i,
            meetingId: meetingId,
            sequence: i,
            startMs: i * 10000,
            endMs: (i + 1) * 10000,
            content: contents[i],
            status: SegmentStatus.transcribed,
            localAudioPath: 'recordings/meeting_$meetingId/chunk_$i.wav',
            createdAt: DateTime(2026, 9, 14),
          ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Call {
  _Call(this.model, this.messages, this.maxTokens);
  final String model;
  final List<LlmMessage> messages;
  final int? maxTokens;
  String get system => messages.first.content;
  String get user => messages.last.content;
}

/// Answers each call with [reply]; an [Exception] or [Error] is thrown instead.
class _Llm extends LlmProvider {
  _Llm(this.reply);
  final Object Function(int index) reply;
  final calls = <_Call>[];

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    final answer = reply(calls.length);
    calls.add(_Call(model, messages, maxTokens));
    if (answer is Exception || answer is Error) throw answer;
    return LlmCompletion(content: answer as String);
  }
}

Future<(_Notes, _Llm)> _run(
  List<String?> contents, {
  Object Function(int index)? reply,
  NotesDepth depth = NotesDepth.standard,
  _Notes? notes,
}) async {
  final dao = notes ?? _Notes();
  final llm = _Llm(reply ?? (_) => '- Petr pošle nabídku do pátku.');
  await NotesGenerator(llm, _Segments(contents), dao)
      .generate(meetingId: 7, depth: depth);
  return (dao, llm);
}

void main() {
  test('notes from the transcript: segments joined, trimmed, blanks dropped',
      () async {
    final (notes, llm) =
        await _run(['  Ahoj všem. ', null, '   ', '', 'Petr pošle nabídku.']);

    expect(notes.events, ['generating', 'ready']);
    expect(notes.content, '- Petr pošle nabídku do pátku.');
    expect(notes.model, kGroqNotesModel);
    expect(notes.depth, NotesDepth.standard);
    expect(llm.calls, hasLength(1));
    expect(llm.calls.single.model, kGroqNotesModel);
    expect(llm.calls.single.user, 'Ahoj všem. Petr pošle nabídku.');
  });

  test('the reply is trimmed before it is stored', () async {
    final (notes, _) = await _run(['Něco.'], reply: (_) => '\n  - Bod.  \n');
    expect(notes.content, '- Bod.');
  });

  test('each depth has its own token budget and its own shape', () async {
    const budgets = {
      NotesDepth.brief: 1500,
      NotesDepth.standard: 3000,
      NotesDepth.full: 6000,
    };
    final systems = <String>{};
    for (final MapEntry(key: depth, value: budget) in budgets.entries) {
      final (notes, llm) = await _run(['Něco.'], depth: depth);
      expect(llm.calls.single.maxTokens, budget, reason: depth.name);
      expect(notes.depth, depth);
      systems.add(llm.calls.single.system);
    }
    expect(systems, hasLength(3));
  });

  test('an empty transcript fails without calling the model', () async {
    final (notes, llm) = await _run([null, '  ', '']);
    expect(llm.calls, isEmpty);
    expect(notes.events, ['generating', 'failed']);
    expect(notes.error, contains('prázdný'));
  });

  test('a blank reply fails instead of replacing the notes with nothing',
      () async {
    for (final blank in ['', '   \n\t ']) {
      final (notes, _) = await _run(['Něco.'], reply: (_) => blank);
      expect(notes.events, ['generating', 'failed'], reason: '"$blank"');
      expect(notes.content, isNull);
      expect(notes.error, 'Model vrátil prázdnou odpověď.');
    }
  });

  test('an AI failure lands on the row with its own message', () async {
    final (notes, _) = await _run(
      ['Něco.'],
      reply: (_) => const AiPermanentException('Invalid API Key', statusCode: 401),
    );
    expect(notes.events, ['generating', 'failed']);
    expect(notes.error, 'Invalid API Key');
  });

  test('any other failure lands on the row too, never thrown', () async {
    final (notes, _) = await _run(['Něco.'], reply: (_) => StateError('boom'));
    expect(notes.events, ['generating', 'failed']);
    expect(notes.error, contains('boom'));
  });

  test('if the row cannot be claimed, the model is never called', () async {
    final (notes, llm) =
        await _run(['Něco.'], notes: _Notes(failGenerating: true));
    expect(llm.calls, isEmpty);
    expect(notes.events, isEmpty);
  });

  test('a failure while recording the failure is swallowed', () async {
    final (notes, _) = await _run(
      ['Něco.'],
      reply: (_) => const AiTransientException('timeout'),
      notes: _Notes(failFailing: true),
    );
    expect(notes.events, ['generating']);
  });

  group('a long meeting', () {
    // ~62 000 characters of distinct words, so a cut in the middle of one is
    // visible and the windows can be stitched back together exactly.
    final contents = [
      for (var s = 0; s < 60; s++)
        [for (var w = 0; w < 100; w++) 'slovo${s}x$w'].join(' '),
    ];
    final transcript = contents.join(' ');

    test('is summarised window by window, then merged', () async {
      expect(transcript.length, greaterThan(kNotesWindowThreshold));

      final (notes, llm) = await _run(
        contents,
        depth: NotesDepth.full,
        reply: (i) => 'shrnutí $i',
      );

      final windows = llm.calls.sublist(0, llm.calls.length - 1);
      final merge = llm.calls.last;
      expect(windows.length, greaterThanOrEqualTo(3));

      // Nothing lost or duplicated at the seams, and no word cut in two.
      expect(windows.map((c) => c.user).join(), transcript);
      var offset = 0;
      for (final w in windows.take(windows.length - 1)) {
        expect(w.user.length, lessThanOrEqualTo(kNotesWindowSize));
        offset += w.user.length;
        expect(transcript[offset], ' ', reason: 'cut at $offset');
      }

      for (var i = 0; i < windows.length; i++) {
        expect(windows[i].maxTokens, 1200);
        expect(windows[i].system, contains('part ${i + 1} of ${windows.length}'));
      }

      expect(merge.maxTokens, 6000);
      expect(merge.system, contains('series of summaries'));
      for (var i = 0; i < windows.length; i++) {
        expect(merge.user,
            contains('--- ${i + 1}/${windows.length} ---\nshrnutí $i'));
      }
      expect(notes.events, ['generating', 'ready']);
      expect(notes.content, 'shrnutí ${windows.length}');
    });

    test('a failing window fails the whole generation, no merge', () async {
      final (notes, llm) = await _run(
        contents,
        reply: (i) =>
            i == 1 ? const AiTransientException('rate limited') : 'shrnutí',
      );
      expect(llm.calls, hasLength(2));
      expect(notes.events, ['generating', 'failed']);
      expect(notes.error, 'rate limited');
    });

    test('a transcript just under the threshold still goes in one call',
        () async {
      final (_, llm) = await _run(['a' * kNotesWindowThreshold]);
      expect(llm.calls, hasLength(1));
    });
  });
}
