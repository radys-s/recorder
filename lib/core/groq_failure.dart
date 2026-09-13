import 'package:dio/dio.dart';

/// The retry decision for one failed Groq request, independent of which
/// endpoint produced it.
///
/// Whisper and chat completions live behind the same gateway and answer with
/// the same error envelope, so the "retry or give up" call is identical for
/// both; only the exception type each caller throws differs.
class GroqFailure {
  const GroqFailure({
    required this.transient,
    required this.message,
    this.statusCode,
  });

  /// True when a later attempt has a real chance: rate limits, server errors,
  /// timeouts, no connectivity. False means the request will never succeed as
  /// sent, and retrying only burns quota.
  final bool transient;

  final String message;
  final int? statusCode;
}

/// Maps a transport/HTTP failure onto the retry contract.
GroqFailure classifyGroqFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return GroqFailure(transient: true, message: 'Network problem: ${e.type.name}');
    case DioExceptionType.cancel:
      return const GroqFailure(transient: true, message: 'Request cancelled.');
    case DioExceptionType.badCertificate:
      return const GroqFailure(
        transient: false,
        message: 'TLS certificate rejected.',
      );
    case DioExceptionType.unknown:
      // Almost always a socket-level failure that a later attempt may survive.
      return GroqFailure(
        transient: true,
        message: 'Request failed: ${e.message ?? e}',
      );
    case DioExceptionType.badResponse:
      break;
  }

  final status = e.response?.statusCode;
  final detail = groqErrorMessage(e.response?.data) ?? e.message ?? 'no detail';

  // 429 and 5xx are the classic "come back later" answers, and Groq adds 413:
  // it answers "request too large … tokens per minute" with that status, which
  // is a rate condition dressed as a size one. Everything else in the 4xx range
  // means this request will never succeed as sent.
  if (status == 429 || status == 413 || (status != null && status >= 500)) {
    return GroqFailure(transient: true, message: detail, statusCode: status);
  }
  if (status == 401 || status == 403) {
    return GroqFailure(
      transient: false,
      message: 'Groq rejected the API key. Check it in Settings. ($detail)',
      statusCode: status,
    );
  }
  return GroqFailure(transient: false, message: detail, statusCode: status);
}

/// Groq mirrors OpenAI's `{"error": {"message": ...}}` envelope.
String? groqErrorMessage(Object? data) {
  if (data is Map) {
    final error = data['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    if (data['message'] is String) return data['message'] as String;
  }
  if (data is String && data.trim().isNotEmpty) return _clip(data.trim());

  // Anything else — an HTML gateway page, a bare list, a body Dio could not
  // decode — used to be dropped on the floor, which left the log showing the
  // bare HTTP reason phrase and nothing about why. A truncated dump of what
  // actually came back is worth more than that.
  if (data != null) return _clip(data.toString());
  return null;
}

String _clip(String value) =>
    value.length <= 300 ? value : '${value.substring(0, 300)}…';
