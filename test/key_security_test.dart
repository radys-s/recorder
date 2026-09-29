import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/ai/custom_endpoint.dart';
import 'package:recorder/core/gemini_failure.dart';
import 'package:recorder/core/groq_failure.dart';
import 'package:recorder/core/logging.dart';
import 'package:recorder/core/redaction.dart';
import 'package:recorder/data/data_privacy.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/data/secure/api_key_store.dart';

const _groq = 'gsk_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789';
const _gemini = 'AIzaSyA1b2C3d4E5f6G7h8I9j0KlMnOpQrStUvW';
const _cerebras = 'csk-abcdef123456ghijkl789012mnopqr';

void main() {
  group('key sanitation', () {
    test('whitespace, zero-width characters and wrapping quotes go', () {
      expect(cleanApiKey('  $_groq \n'), _groq);
      expect(cleanApiKey('$_groq​'), _groq);
      expect(cleanApiKey('﻿$_groq'), _groq);
      expect(cleanApiKey('gsk_ab cd'), 'gsk_abcd');
      expect(cleanApiKey('"$_groq"'), _groq);
      expect(cleanApiKey("'$_groq'"), _groq);
      expect(cleanApiKey('gsk_ab cd\tef'), 'gsk_abcdef');
    });

    test('anything left outside printable ASCII is a problem', () {
      expect(apiKeyProblem(_groq), isNull);
      expect(apiKeyProblem(''), isNotNull);
      expect(apiKeyProblem('gsk_žluťoučký'), isNotNull);
      expect(apiKeyProblem('gsk_“smart”'), isNotNull);
      expect(apiKeyProblem('gsk_a"b'), isNull, reason: 'a quote is ASCII');
    });

    test('format hints warn but never decide', () {
      expect(apiKeyFormatHint('Groq', _groq), isNull);
      expect(apiKeyFormatHint('Groq', 'AIzaSy123'), contains('gsk_'));
      expect(apiKeyFormatHint('Gemini', _gemini), isNull);
      expect(apiKeyFormatHint('Gemini', _groq), contains('AIza'));
      expect(apiKeyFormatHint('Cerebras', _cerebras), isNull);
      expect(apiKeyFormatHint('Cerebras', _groq), contains('csk-'));
      expect(apiKeyFormatHint('Mistral', 'anything'), isNull);
      expect(apiKeyFormatHint('Vlastní', 'anything'), isNull);
    });

    group('the store', () {
      setUp(() => FlutterSecureStorage.setMockInitialValues({}));

      test('saves the cleaned key', () async {
        final store = ApiKeyStore();
        await store.write('  $_groq​\n');
        expect(await store.read(), _groq);
      });

      test('refuses a key that could not be sent, and stores nothing',
          () async {
        final store = ApiKeyStore();
        await expectLater(
          store.write('gsk_žluťoučký'),
          throwsA(isA<ApiKeyFormatException>()),
        );
        expect(await store.read(), isNull);
        expect(await store.hasKey(), isFalse);
      });

      test('the refusal never quotes the key', () async {
        final store = ApiKeyStore();
        try {
          await store.write('gsk_secretžluť');
          fail('should have thrown');
        } on ApiKeyFormatException catch (e) {
          expect(e.message, isNot(contains('secret')));
          expect(userMessage(e), isNot(contains('secret')));
        }
      });

      test('an old value with a stray character is repaired on read', () async {
        FlutterSecureStorage.setMockInitialValues({
          'groq_api_key': ' $_groq​',
        });
        expect(await ApiKeyStore().read(), _groq);
      });

      test('an old value that can never work reads as no key', () async {
        FlutterSecureStorage.setMockInitialValues({
          'groq_api_key': 'gsk_žluť',
        });
        expect(await ApiKeyStore().read(), isNull);
      });
    });
  });

  group('redactSecrets', () {
    test('masks the vendor prefixes', () {
      for (final key in [_groq, _gemini, _cerebras]) {
        final out = redactSecrets('rejected $key by the server');
        expect(out, isNot(contains(key)), reason: key);
        expect(out, contains('rejected'));
        expect(out, contains('by the server'));
      }
    });

    test('masks a bearer token and an authorization header', () {
      expect(
        redactSecrets('Authorization: Bearer $_groq'),
        isNot(contains(_groq)),
      );
      expect(redactSecrets('sent Bearer abc.def-ghi'), 'sent Bearer ***');
      expect(
        redactSecrets('x-goog-api-key: $_gemini'),
        'x-goog-api-key: ***',
      );
      expect(
        redactSecrets('{"Authorization":"Bearer $_groq"}'),
        isNot(contains(_groq)),
      );
    });

    test('masks a key passed as a query parameter', () {
      final out = redactSecrets('GET /v1/models?key=$_gemini&alt=json');
      expect(out, isNot(contains(_gemini)));
      expect(out, contains('alt=json'));
    });

    test('masks a long token with no known prefix (Mistral)', () {
      const token = 'Qw3rTy0PaSdFgHjKlZxCvBnM1234567890AbCd';
      expect(redactSecrets('key $token was refused'), 'key *** was refused');
    });

    test('leaves ordinary text alone', () {
      const text = 'Network problem: connectionTimeout (HTTP 429) on row 12';
      expect(redactSecrets(text), text);
    });

    test('a FormatException that quotes the header is reduced to its type', () {
      final error = FormatException(
        'Invalid HTTP header field value: "Bearer $_groq​" (at 44)',
      );
      final shown = describeError(error);
      expect(shown, startsWith('FormatException'));
      expect(shown, isNot(contains(_groq)));
      expect(shown, isNot(contains('gsk_')));

      expect(userMessage(error), isNot(contains(_groq)));
    });

    test('describeError is one short line', () {
      final shown = describeError(StateError('a\n' * 400), maxChars: 60);
      expect(shown.contains('\n'), isFalse);
      expect(shown.length, lessThan(90));
    });
  });

  group('failures never carry a key', () {
    DioException dio({
      required DioExceptionType type,
      Object? error,
      Response<Object?>? response,
      String? message,
    }) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      error: error,
      response: response,
      message: message,
    );

    test('a header FormatException is not echoed', () {
      final failure = classifyGroqFailure(
        dio(
          type: DioExceptionType.unknown,
          error: FormatException('bad header "Bearer $_groq"'),
          message: 'bad header "Bearer $_groq"',
        ),
      );
      expect(failure.message, isNot(contains(_groq)));
      expect(failure.message, contains('FormatException'));
    });

    test('a server that echoes the key back is masked', () {
      final failure = classifyGroqFailure(
        dio(
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 401,
            data: {
              'error': {'message': 'Invalid API Key: $_groq'},
            },
          ),
        ),
      );
      expect(failure.transient, isFalse);
      expect(failure.message, isNot(contains(_groq)));
    });

    test('the Google reason is masked too', () {
      final failure = classifyGeminiFailure(
        dio(
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 400,
            data: {
              'error': {
                'status': 'INVALID_ARGUMENT',
                'message': 'API key not valid: $_gemini',
              },
            },
          ),
        ),
      );
      expect(failure.reason, isNot(contains(_gemini)));
    });

    test('a stored error is redacted at the write', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(title: 'Hodina', createdAt: DateTime(2026)),
      );
      await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
      await db.meetingNotesDao.markFailed(id, 'refused: Bearer $_groq');
      final row = await db.select(db.meetingNotes).getSingle();
      expect(row.error, isNot(contains(_groq)));
      expect(row.error, contains('refused'));
    });

    test('the data export redacts error columns', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.meetingsDao.insertMeeting(
        MeetingsCompanion.insert(title: 'Hodina', createdAt: DateTime(2026)),
      );
      await db.meetingNotesDao.markGenerating(id, NotesDepth.standard, 'm');
      // An old row written before redaction existed.
      await db.customStatement(
        'UPDATE meeting_notes SET error = ?',
        ['old: Bearer $_groq'],
      );
      final export = await exportAllData(db, now: DateTime(2026));
      expect('$export', isNot(contains(_groq)));
      expect('$export', contains('old:'));
    });
  });

  group('custom endpoint', () {
    test('https, no userinfo, no query', () {
      final ok = checkCustomEndpoint(' https://AI.Skola.cz/v1/ ');
      expect(ok.valid, isTrue);
      expect(ok.url, 'https://ai.skola.cz/v1');
      expect(ok.host, 'ai.skola.cz');
    });

    test('plain http is refused', () {
      final r = checkCustomEndpoint('http://ai.skola.cz/v1');
      expect(r.valid, isFalse);
      expect(r.problem, contains('https'));
    });

    test('a user:password part is refused', () {
      expect(checkCustomEndpoint('https://user:pw@ai.skola.cz/v1').valid,
          isFalse);
      expect(checkCustomEndpoint('https://token@ai.skola.cz/v1').valid,
          isFalse);
    });

    test('a query or fragment is refused', () {
      expect(checkCustomEndpoint('https://ai.skola.cz/v1?key=abc').valid,
          isFalse);
      expect(checkCustomEndpoint('https://ai.skola.cz/v1#x').valid, isFalse);
    });

    test('empty and nonsense are refused', () {
      for (final bad in ['', '   ', 'ai.skola.cz', 'https://', 'ftp://x.cz']) {
        expect(checkCustomEndpoint(bad).valid, isFalse, reason: bad);
      }
      expect(checkCustomEndpoint(null).valid, isFalse);
    });
  });

  group('the log', () {
    setUp(() {
      AppLog.clear();
      AppLog.debugOverride = null;
    });
    tearDown(() => AppLog.debugOverride = null);

    test('a release build drops debug lines and keeps the rest', () {
      AppLog.debugOverride = false;
      AppLog.d('t', 'detail');
      AppLog.i('t', 'event');
      AppLog.w('t', 'careful');
      AppLog.e('t', 'broke');
      expect(AppLog.recent.length, 3);
      expect(AppLog.recent.join('\n'), isNot(contains('detail')));
    });

    test('a debug build keeps debug lines', () {
      AppLog.debugOverride = true;
      AppLog.d('t', 'detail');
      expect(AppLog.recent.single, contains('detail'));
    });

    test('keeps the last 500 lines', () {
      for (var i = 0; i < 620; i++) {
        AppLog.i('t', 'line $i');
      }
      expect(AppLog.recent.length, AppLog.capacity);
      expect(AppLog.recent.first, contains('line 120'));
      expect(AppLog.recent.last, contains('line 619'));
    });

    test('every line is redacted, including an attached error', () {
      AppLog.i('t', 'sent Bearer $_groq');
      AppLog.e(
        't',
        'failed',
        FormatException('bad header "Bearer $_gemini"'),
      );
      final all = AppLog.recent.join('\n');
      expect(all, isNot(contains(_groq)));
      expect(all, isNot(contains(_gemini)));
      expect(all, contains('FormatException'));
    });
  });
}
