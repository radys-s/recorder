import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/sync/drive_api.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);

  final List<(int, Object)> responses;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(
      requestStream == null
          ? ''
          : utf8.decode(await requestStream.expand((b) => b).toList()),
    );
    final (status, body) = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(DioDriveApi, _Adapter) _api(List<(int, Object)> responses) {
  final adapter = _Adapter(responses);
  return (
    DioDriveApi(
      Dio()..httpClientAdapter = adapter,
      () async => 'tok',
      random: Random(1),
    ),
    adapter,
  );
}

Future<DriveException> _failure(int status, Object body) async {
  final (api, _) = _api([(status, body)]);
  try {
    await api.createFolder('x');
  } on DriveException catch (e) {
    return e;
  }
  fail('no exception for $status');
}

void main() {
  test('createDoc sends one multipart/related body: metadata, then html',
      () async {
    final (api, adapter) = _api([
      (200, {'id': 'doc1'}),
    ]);
    final id = await api.createDoc(
      name: 'Schůzky – Sítě',
      folderId: 'f1',
      html: '<p>Ahoj</p>',
    );
    expect(id, 'doc1');

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.queryParameters['uploadType'], 'multipart');
    expect(request.headers['Authorization'], 'Bearer tok');
    final type = request.contentType!;
    expect(type, startsWith('multipart/related; boundary='));
    final boundary = type.split('boundary=').last;

    final body = adapter.bodies.single;
    final parts = body.split('--$boundary');
    expect(parts.last.trim(), '--');
    final meta = parts[1];
    expect(meta, contains('application/json'));
    final json = jsonDecode(meta.split('\r\n\r\n').last.trim()) as Map;
    expect(json['name'], 'Schůzky – Sítě');
    expect(json['mimeType'], 'application/vnd.google-apps.document');
    expect(json['parents'], ['f1']);
    expect(parts[2], contains('text/html'));
    expect(parts[2], contains('<p>Ahoj</p>'));
  });

  test('updateDoc patches in place and does not move the doc', () async {
    final (api, adapter) = _api([
      (200, {'id': 'doc1', 'trashed': false}),
    ]);
    await api.updateDoc('doc1', name: 'n', html: '<p>x</p>');
    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.uri.path, endsWith('/doc1'));
    expect(adapter.bodies.single, isNot(contains('parents')));
  });

  test('a binned doc counts as gone', () async {
    final (api, _) = _api([
      (200, {'id': 'doc1', 'trashed': true}),
    ]);
    await expectLater(
      api.updateDoc('doc1', name: 'n', html: 'h'),
      throwsA(isA<DriveNotFoundException>()),
    );
  });

  test('folderExists: 404 and binned are false, present is true', () async {
    final (a, _) = _api([
      (404, {'error': {'code': 404}}),
    ]);
    expect(await a.folderExists('f'), isFalse);
    final (b, _) = _api([
      (200, {'id': 'f', 'trashed': true}),
    ]);
    expect(await b.folderExists('f'), isFalse);
    final (c, _) = _api([
      (200, {'id': 'f', 'trashed': false}),
    ]);
    expect(await c.folderExists('f'), isTrue);
  });

  test('a reply without an id is a permanent failure', () async {
    final (api, _) = _api([
      (200, <String, Object>{}),
    ]);
    await expectLater(
      api.createFolder('Schůzky'),
      throwsA(isA<DrivePermanentException>()),
    );
  });

  group('failure mapping', () {
    test('401 asks for sign-in, 404 is not found', () async {
      expect(await _failure(401, {}), isA<DriveAuthException>());
      expect(await _failure(404, {}), isA<DriveNotFoundException>());
    });

    test('429, 5xx and a 403 rate limit are transient', () async {
      expect(await _failure(429, {}), isA<DriveTransientException>());
      expect(await _failure(503, {}), isA<DriveTransientException>());
      expect(
        await _failure(403, {
          'error': {
            'errors': [
              {'reason': 'userRateLimitExceeded'},
            ],
          },
        }),
        isA<DriveTransientException>(),
      );
    });

    test('403 says what is wrong', () async {
      final disabled = await _failure(403, {
        'error': {
          'errors': [
            {'reason': 'accessNotConfigured'},
          ],
        },
      });
      expect(disabled, isA<DrivePermanentException>());
      expect(disabled.message, contains('Google Drive API'));

      final full = await _failure(403, {
        'error': {
          'errors': [
            {'reason': 'storageQuotaExceeded'},
          ],
        },
      });
      expect(full.message, 'Google Disk je plný.');

      expect((await _failure(403, {})).message, contains('403'));
      expect((await _failure(400, {})).message, contains('HTTP 400'));
    });
  });
}
