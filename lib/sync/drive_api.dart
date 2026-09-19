import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../core/constants.dart';

/// Every Drive failure carries a sentence for the student.
sealed class DriveException implements Exception {
  const DriveException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// The account has to sign in again.
class DriveAuthException extends DriveException {
  const DriveAuthException(super.message);
}

/// The file (or its folder) is gone or in the bin.
class DriveNotFoundException extends DriveException {
  const DriveNotFoundException([super.message = 'Soubor na Disku už není.']);
}

/// Offline, rate-limited or Google having a bad minute: try again later.
class DriveTransientException extends DriveException {
  const DriveTransientException([
    super.message = 'Google Disk teď neodpovídá. Zkusím to znovu.',
  ]);
}

/// Retrying will not help until something changes.
class DrivePermanentException extends DriveException {
  const DrivePermanentException(super.message);
}

/// The few Drive calls the sync needs. Only files the app created are ever
/// touched — the `drive.file` scope does not let it see anything else.
abstract class DriveApi {
  Future<String> createFolder(String name);

  /// Whether the folder is still there and not in the bin — a doc created
  /// in a binned folder would be binned too.
  Future<bool> folderExists(String id);

  /// A new Google Doc converted from [html]; returns its id.
  Future<String> createDoc({
    required String name,
    required String folderId,
    required String html,
  });

  /// Replaces the doc's whole content, keeping its id (so NotebookLM's source
  /// stays the same file).
  Future<void> updateDoc(String id, {required String name, required String html});
}

const _docMime = 'application/vnd.google-apps.document';
const _folderMime = 'application/vnd.google-apps.folder';

class DioDriveApi implements DriveApi {
  DioDriveApi(this._dio, this._accessToken, {Random? random})
    : _random = random ?? Random.secure();

  final Dio _dio;
  final Future<String> Function() _accessToken;
  final Random _random;

  @override
  Future<String> createFolder(String name) async {
    final data = await _call(
      () async => _dio.post<dynamic>(
        kDriveFilesUrl,
        queryParameters: {'fields': 'id'},
        data: {'name': name, 'mimeType': _folderMime},
        options: await _options(),
      ),
    );
    return _id(data);
  }

  @override
  Future<bool> folderExists(String id) async {
    try {
      final data = await _call(
        () async => _dio.get<dynamic>(
          '$kDriveFilesUrl/$id',
          queryParameters: {'fields': 'id,trashed'},
          options: await _options(),
        ),
      );
      return !(data is Map && data['trashed'] == true);
    } on DriveNotFoundException {
      return false;
    }
  }

  @override
  Future<String> createDoc({
    required String name,
    required String folderId,
    required String html,
  }) async {
    final body = _multipart({
      'name': name,
      'mimeType': _docMime,
      'parents': [folderId],
    }, html);
    final data = await _call(
      () async => _dio.post<dynamic>(
        kDriveUploadUrl,
        queryParameters: {'uploadType': 'multipart', 'fields': 'id'},
        data: body.content,
        options: await _options(contentType: body.contentType),
      ),
    );
    return _id(data);
  }

  @override
  Future<void> updateDoc(
    String id, {
    required String name,
    required String html,
  }) async {
    final body = _multipart({'name': name}, html);
    final data = await _call(
      () async => _dio.patch<dynamic>(
        '$kDriveUploadUrl/$id',
        queryParameters: {'uploadType': 'multipart', 'fields': 'id,trashed'},
        data: body.content,
        options: await _options(contentType: body.contentType),
      ),
    );
    // A binned doc still accepts updates, but NotebookLM can no longer read it.
    if (data is Map && data['trashed'] == true) {
      throw const DriveNotFoundException('Dokument je v koši na Disku.');
    }
  }

  Future<Options> _options({String? contentType}) async => Options(
    headers: {'Authorization': 'Bearer ${await _accessToken()}'},
    contentType: contentType ?? Headers.jsonContentType,
    responseType: ResponseType.json,
  );

  ({String content, String contentType}) _multipart(
    Map<String, Object?> metadata,
    String html,
  ) {
    final boundary = 'schuzky-${_random.nextInt(0x7fffffff).toRadixString(16)}'
        '${_random.nextInt(0x7fffffff).toRadixString(16)}';
    final content = StringBuffer()
      ..write('--$boundary\r\n')
      ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
      ..write(jsonEncode(metadata))
      ..write('\r\n--$boundary\r\n')
      ..write('Content-Type: text/html; charset=UTF-8\r\n\r\n')
      ..write(html)
      ..write('\r\n--$boundary--\r\n');
    return (
      content: content.toString(),
      contentType: 'multipart/related; boundary=$boundary',
    );
  }

  String _id(Object? data) {
    final id = data is Map ? data['id'] : null;
    if (id is! String || id.isEmpty) {
      throw const DrivePermanentException('Google Disk nevrátil id souboru.');
    }
    return id;
  }

  Future<Object?> _call(Future<Response<dynamic>> Function() send) async {
    try {
      return (await send()).data;
    } on DioException catch (e) {
      throw driveFailure(e);
    }
  }
}

/// Maps a Drive HTTP failure onto what the sync should do next.
DriveException driveFailure(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return const DriveTransientException();
  final body = e.response?.data;
  final text = body is String ? body : jsonEncode(body);
  if (status == 401) {
    return const DriveAuthException('Přihlášení ke Googlu vypršelo.');
  }
  if (status == 404) return const DriveNotFoundException();
  if (status == 429 || status >= 500) return const DriveTransientException();
  if (status == 403) {
    if (text.contains('accessNotConfigured') ||
        text.contains('SERVICE_DISABLED')) {
      return const DrivePermanentException(
        'V Google Cloud projektu není zapnuté Google Drive API.',
      );
    }
    if (text.contains('rateLimitExceeded') ||
        text.contains('userRateLimitExceeded')) {
      return const DriveTransientException();
    }
    if (text.contains('storageQuotaExceeded')) {
      return const DrivePermanentException('Google Disk je plný.');
    }
    return const DrivePermanentException(
      'Google Disk zápis odmítl (403). Zkus se odhlásit a přihlásit znovu.',
    );
  }
  return DrivePermanentException('Google Disk odmítl požadavek (HTTP $status).');
}
