import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/stt/fallback_stt_provider.dart';
import 'package:recorder/stt/stt_provider.dart';

class _Engine implements SttProvider {
  _Engine(this.id, this.respond);
  final String id;
  final TranscriptionResult Function() respond;
  var calls = 0;

  @override
  Future<TranscriptionResult> transcribe({
    required File audioFile,
    String? promptContext,
    String? languageCode,
    MicSensitivity sensitivity = MicSensitivity.medium,
    String? glossary,
    double? noSpeechProbThreshold,
    double? lowAvgLogprobThreshold,
    Duration? timeout,
  }) async {
    calls++;
    return respond();
  }
}

void main() {
  final file = File('nothing.wav');
  var clock = DateTime(2026, 9, 29, 9);

  SttEngine engine(_Engine e, {bool key = true}) =>
      SttEngine(e.id, e, () async => key);

  FallbackSttProvider chain(List<SttEngine> engines) =>
      FallbackSttProvider(engines, now: () => clock);

  TranscriptionResult ok(String id) =>
      TranscriptionResult(text: 'text $id', engine: id);
  Never limited([Duration? after]) =>
      throw SttRateLimited('limit', retryAfter: after, statusCode: 429);

  setUp(() => clock = DateTime(2026, 9, 29, 9));

  test('the first engine with a key answers', () async {
    final a = _Engine('a', () => ok('a'));
    final b = _Engine('b', () => ok('b'));
    final result = await chain([
      engine(a),
      engine(b),
    ]).transcribe(audioFile: file);
    expect(result.engine, 'a');
    expect(b.calls, 0);
  });

  test('a rate limit moves the same chunk to the next engine', () async {
    final a = _Engine('a', () => limited(const Duration(minutes: 2)));
    final b = _Engine('b', () => ok('b'));
    final c = _Engine('c', () => ok('c'));
    final stt = chain([engine(a), engine(b), engine(c)]);

    expect((await stt.transcribe(audioFile: file)).engine, 'b');
    expect(stt.coolingDown('a'), isTrue);
    expect(c.calls, 0);
  });

  test('a resting engine is skipped until its cooldown ends', () async {
    final a = _Engine('a', () => limited(const Duration(minutes: 2)));
    final b = _Engine('b', () => ok('b'));
    final stt = chain([engine(a), engine(b)]);
    await stt.transcribe(audioFile: file);
    expect(a.calls, 1);

    clock = clock.add(const Duration(minutes: 1));
    await stt.transcribe(audioFile: file);
    expect(a.calls, 1, reason: 'still resting after one minute');

    clock = clock.add(const Duration(minutes: 2));
    await stt.transcribe(audioFile: file);
    expect(a.calls, 2, reason: 'tried again once the two minutes passed');
  });

  test("a success clears the engine's cooldown history", () async {
    var fail = true;
    final a = _Engine('a', () => fail ? limited() : ok('a'));
    final b = _Engine('b', () => ok('b'));
    final stt = chain([engine(a), engine(b)]);

    await stt.transcribe(audioFile: file); // 60 s
    clock = clock.add(const Duration(seconds: 61));
    await stt.transcribe(audioFile: file); // doubled to 120 s
    expect(
      stt.cooldownUntil('a')!.difference(clock),
      const Duration(seconds: 120),
    );

    clock = clock.add(const Duration(seconds: 121));
    fail = false;
    expect((await stt.transcribe(audioFile: file)).engine, 'a');
    expect(stt.coolingDown('a'), isFalse);
  });

  test(
    'every engine resting is one rate limit with the shortest wait',
    () async {
      final a = _Engine('a', () => limited(const Duration(minutes: 5)));
      final b = _Engine('b', () => limited(const Duration(minutes: 2)));
      await expectLater(
        chain([engine(a), engine(b)]).transcribe(audioFile: file),
        throwsA(
          isA<SttRateLimited>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(minutes: 2),
          ),
        ),
      );
    },
  );

  test('an engine without a key is skipped and never called', () async {
    final a = _Engine('a', () => ok('a'));
    final b = _Engine('b', () => ok('b'));
    final result = await chain([
      engine(a, key: false),
      engine(b),
    ]).transcribe(audioFile: file);
    expect(result.engine, 'b');
    expect(a.calls, 0);
  });

  test('no key anywhere is a missing key, not a failure', () async {
    final a = _Engine('a', () => ok('a'));
    await expectLater(
      chain([engine(a, key: false)]).transcribe(audioFile: file),
      throwsA(isA<SttKeyMissing>()),
    );
  });

  test('a refused key rests that engine and another one takes over', () async {
    final a = _Engine(
      'a',
      () => throw const SttPermanentException('bad', statusCode: 401),
    );
    final b = _Engine('b', () => ok('b'));
    final stt = chain([engine(a), engine(b)]);
    expect((await stt.transcribe(audioFile: file)).engine, 'b');
    expect(stt.coolingDown('a'), isTrue);
  });

  test('a refused key with no other engine is reported as refused', () async {
    final a = _Engine(
      'a',
      () => throw const SttPermanentException('bad', statusCode: 401),
    );
    await expectLater(
      chain([engine(a)]).transcribe(audioFile: file),
      throwsA(
        isA<SttPermanentException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('rejected audio is not passed on to the next engine', () async {
    final a = _Engine(
      'a',
      () => throw const SttPermanentException('bad audio', statusCode: 400),
    );
    final b = _Engine('b', () => ok('b'));
    await expectLater(
      chain([engine(a), engine(b)]).transcribe(audioFile: file),
      throwsA(isA<SttPermanentException>()),
    );
    expect(b.calls, 0);
  });

  test(
    'a server error tries the next engine and reports it if all fail',
    () async {
      final a = _Engine(
        'a',
        () => throw const SttTransientException('bad gateway', statusCode: 503),
      );
      final b = _Engine('b', () => ok('b'));
      expect(
        (await chain([
          engine(a),
          engine(b),
        ]).transcribe(audioFile: file)).engine,
        'b',
      );
      await expectLater(
        chain([engine(a)]).transcribe(audioFile: file),
        throwsA(isA<SttTransientException>()),
      );
    },
  );
}
