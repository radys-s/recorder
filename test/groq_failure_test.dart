import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/groq_failure.dart';

DioException _http(int status, Object? body, {String? message}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    message: message,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

DioException _transport(DioExceptionType type) =>
    DioException(requestOptions: RequestOptions(path: '/x'), type: type);

void main() {
  group('groqErrorMessage', () {
    test('reads the OpenAI envelope, trimmed', () {
      expect(
        groqErrorMessage({
          'error': {'message': '  Rate limit reached.  '},
        }),
        'Rate limit reached.',
      );
    });

    test('falls back to a top-level message', () {
      expect(groqErrorMessage({'message': 'Bad gateway'}), 'Bad gateway');
      expect(
        groqErrorMessage({
          'error': {'message': '   '},
          'message': 'outer',
        }),
        'outer',
      );
    });

    test('a map with no usable message is dumped rather than lost', () {
      expect(groqErrorMessage({'error': 42}), contains('42'));
    });

    test('a blank body is no detail at all', () {
      expect(groqErrorMessage(''), isNull);
      expect(groqErrorMessage(' \n '), isNull);
      expect(groqErrorMessage(null), isNull);
    });

    test('a plain-text or HTML body is kept, clipped', () {
      expect(groqErrorMessage(' upstream timeout '), 'upstream timeout');
      final html = '<html>${'x' * 1000}</html>';
      final clipped = groqErrorMessage(html)!;
      expect(clipped, hasLength(301));
      expect(clipped, endsWith('…'));
    });

    test('a long nested message is clipped too', () {
      final long = groqErrorMessage({
        'error': {'message': 'y' * 500},
      })!;
      expect(long, hasLength(301));
    });

    test('a list body is dumped', () {
      expect(groqErrorMessage(['a', 'b']), '[a, b]');
    });
  });

  group('classifyGroqFailure', () {
    for (final status in [413, 429, 500, 502, 503]) {
      test('HTTP $status is transient', () {
        final f = classifyGroqFailure(_http(status, {
          'error': {'message': 'later'},
        }));
        expect(f.transient, isTrue);
        expect(f.statusCode, status);
        expect(f.message, 'later');
      });
    }

    for (final status in [401, 403]) {
      test('HTTP $status names the key and keeps the detail', () {
        final f = classifyGroqFailure(_http(status, {
          'error': {'message': 'Invalid API Key'},
        }));
        expect(f.transient, isFalse);
        expect(f.message, contains('Settings'));
        expect(f.message, contains('Invalid API Key'));
      });
    }

    test('other 4xx are permanent', () {
      final f = classifyGroqFailure(_http(404, {
        'error': {'message': 'model not found'},
      }));
      expect(f.transient, isFalse);
      expect(f.statusCode, 404);
    });

    test("an empty body falls back to Dio's own message", () {
      expect(
        classifyGroqFailure(_http(502, '', message: 'Bad Gateway')).message,
        'Bad Gateway',
      );
      expect(classifyGroqFailure(_http(502, '')).message, 'no detail');
    });

    test('transport failures', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ]) {
        final f = classifyGroqFailure(_transport(type));
        expect(f.transient, isTrue, reason: type.name);
        expect(f.statusCode, isNull);
      }
      expect(
        classifyGroqFailure(_transport(DioExceptionType.badCertificate))
            .transient,
        isFalse,
      );
    });
  });
}
