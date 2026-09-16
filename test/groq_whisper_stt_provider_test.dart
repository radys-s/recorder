import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/secure/api_key_store.dart';
import 'package:recorder/stt/groq_whisper_stt_provider.dart';
import 'package:recorder/stt/stt_provider.dart';

class _FakeKeyStore implements ApiKeyStore {
  _FakeKeyStore(this.key);
  final String? key;

  @override
  Future<String?> read() async => key;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers every request with one canned response and keeps what was sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? lastOptions;
  String lastBody = '';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (requestStream != null) {
      final bytes = await requestStream.expand((b) => b).toList();
      lastBody = latin1.decode(bytes);
    }
    return ResponseBody.fromString(
      body is String ? body as String : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late File audio;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stt_test');
    audio = File('${dir.path}/chunk_0000.wav')
      ..writeAsBytesSync(List.filled(64, 0));
  });

  tearDown(() => dir.delete(recursive: true));

  (GroqWhisperSttProvider, _Adapter) provider(
    int status,
    Object body, {
    String? key = 'gsk_test',
  }) {
    final adapter = _Adapter(status, body);
    final dio = Dio()..httpClientAdapter = adapter;
    return (GroqWhisperSttProvider(_FakeKeyStore(key), dio: dio), adapter);
  }

  test('no key is a permanent failure, and nothing is sent', () async {
    final (stt, adapter) = provider(200, {'text': 'x'}, key: null);
    await expectLater(
      stt.transcribe(audioFile: audio),
      throwsA(isA<SttPermanentException>()),
    );
    expect(adapter.lastOptions, isNull);
  });

  test('a missing audio file is a permanent failure', () async {
    final (stt, _) = provider(200, {'text': 'x'});
    await expectLater(
      stt.transcribe(audioFile: File('${dir.path}/gone.wav')),
      throwsA(isA<SttPermanentException>()),
    );
  });

  test('sends the key, greedy decoding, the language and a trimmed prompt',
      () async {
    final (stt, adapter) = provider(200, {'text': ' Ahoj. '});
    final longPrompt = '${'x' * 500}KONEC';
    final result = await stt.transcribe(
      audioFile: audio,
      languageCode: 'cs',
      promptContext: longPrompt,
    );

    expect(result.text, 'Ahoj.');
    expect(adapter.lastOptions!.headers['Authorization'], 'Bearer gsk_test');
    expect(adapter.lastBody, contains('name="temperature"\r\n\r\n0\r\n'));
    expect(adapter.lastBody, contains('name="language"\r\n\r\ncs\r\n'));
    // Only the tail: the part that continues into this chunk.
    final prompt = RegExp(r'name="prompt"\r\n\r\n(.*?)\r\n')
        .firstMatch(adapter.lastBody)!
        .group(1)!;
    expect(prompt, hasLength(350));
    expect(prompt, endsWith('KONEC'));
  });

  test('no language and a blank prompt are left out entirely', () async {
    final (stt, adapter) = provider(200, {'text': 'x'});
    await stt.transcribe(audioFile: audio, promptContext: '   ');
    expect(adapter.lastBody, isNot(contains('name="language"')));
    expect(adapter.lastBody, isNot(contains('name="prompt"')));
  });

  group('sensitivity reaches the segment filter', () {
    final response = {
      'text': ' Tak jo. Stihneme to do pátku.',
      'language': 'czech',
      'duration': 9.5,
      'segments': [
        {
          'text': ' Tak jo.',
          'no_speech_prob': 0.1,
          'avg_logprob': -0.3,
          'compression_ratio': 1.1,
        },
        {
          'text': ' Stihneme to do pátku.',
          'no_speech_prob': 0.7,
          'avg_logprob': -1.1,
          'compression_ratio': 1.2,
        },
      ],
    };

    test('medium drops a quietly spoken segment', () async {
      final (stt, _) = provider(200, response);
      final result = await stt.transcribe(audioFile: audio);
      expect(result.text, 'Tak jo.');
      expect(result.droppedSegments, 1);
      expect(result.language, 'czech');
      expect(result.durationSeconds, 9.5);
    });

    test('high keeps it, and the untouched text is used', () async {
      final (stt, _) = provider(200, response);
      final result = await stt.transcribe(
        audioFile: audio,
        sensitivity: MicSensitivity.high,
      );
      expect(result.text, 'Tak jo. Stihneme to do pátku.');
      expect(result.droppedSegments, 0);
    });
  });

  group('failures', () {
    test('a response without text is permanent', () async {
      final (stt, _) = provider(200, {'segments': <Object>[]});
      await expectLater(
        stt.transcribe(audioFile: audio),
        throwsA(isA<SttPermanentException>()),
      );
    });

    test('a bad key is permanent and carries the status', () async {
      final (stt, _) = provider(401, {
        'error': {'message': 'Invalid API Key'},
      });
      await expectLater(
        stt.transcribe(audioFile: audio),
        throwsA(
          isA<SttPermanentException>()
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    for (final status in [429, 500, 503]) {
      test('HTTP $status is retried', () async {
        final (stt, _) = provider(status, {
          'error': {'message': 'try later'},
        });
        await expectLater(
          stt.transcribe(audioFile: audio),
          throwsA(
            isA<SttTransientException>()
                .having((e) => e.statusCode, 'statusCode', status),
          ),
        );
      });
    }
  });
}
