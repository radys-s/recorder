import 'dart:convert';

import 'package:dio/dio.dart';

import 'groq_failure.dart';

/// What went wrong with a Gemini request, in the terms the user can act on.
///
/// Before this existed every refusal read „Zkontroluj klíč", so a model id
/// Google no longer offers (404) or a request field a model does not accept
/// (400) looked exactly like a wrong key — and the user, holding a perfectly
/// good key, was told it could not be used.
enum GeminiErrorKind {
  /// The key itself was refused.
  badKey,

  /// The model id is not offered to this key.
  modelMissing,

  /// The Generative Language API is not enabled for the key's project.
  apiDisabled,

  /// Google does not serve the API where the request came from.
  region,

  /// Free-tier requests or search grounding used up for now.
  quota,

  /// The request itself was rejected (a field, a tool, a file too big).
  badRequest,

  /// Timeouts, connectivity, server errors.
  network,

  /// The model is busy for everyone right now (503 / UNAVAILABLE). Nothing is
  /// wrong with the key or the request; another model or service will do.
  overloaded,
}

/// The retry decision for one failed Gemini request, plus what kind of
/// failure it was and Google's own short reason.
class GeminiFailure extends GroqFailure {
  const GeminiFailure({
    required super.transient,
    required super.message,
    required this.kind,
    super.statusCode,
    this.reason,
  });

  final GeminiErrorKind kind;

  /// Google's `error.message`, clipped; never contains the key (it travels in
  /// a header, and Google does not echo it back).
  final String? reason;
}

/// Maps a failed request onto [GeminiFailure].
///
/// Transport failures and the 429/5xx split are the same as Groq's, so this
/// starts from [classifyGroqFailure] and only overrides what Google says
/// differently: an invalid key comes back as a **400** (`API_KEY_INVALID`),
/// not a 401.
GeminiFailure classifyGeminiFailure(DioException e) {
  final base = classifyGroqFailure(e);
  if (e.type != DioExceptionType.badResponse) {
    return GeminiFailure(
      transient: base.transient,
      message: base.message,
      kind: GeminiErrorKind.network,
      statusCode: base.statusCode,
    );
  }

  final status = e.response?.statusCode;
  final body = e.response?.data;
  final raw = body is String ? body : _safeEncode(body);
  final (:googleStatus, :reason) = geminiErrorDetail(body);
  final lower = (reason ?? '').toLowerCase();

  GeminiFailure permanent(GeminiErrorKind kind, String message) =>
      GeminiFailure(
        transient: false,
        message: message,
        kind: kind,
        statusCode: status,
        reason: reason,
      );

  if ((status == 400 &&
          (raw.contains('API_KEY_INVALID') ||
              lower.contains('api key not valid'))) ||
      status == 401 ||
      (status == 403 && lower.contains('api key'))) {
    return permanent(
      GeminiErrorKind.badKey,
      'Gemini klíč neprošel. Zkontroluj ho v Nastavení. (${base.message})',
    );
  }
  if (status == 403 &&
      (raw.contains('SERVICE_DISABLED') ||
          lower.contains('has not been used') ||
          lower.contains('is disabled'))) {
    return permanent(GeminiErrorKind.apiDisabled, base.message);
  }
  if (status == 403) {
    return permanent(GeminiErrorKind.badKey,
        'Gemini klíč neprošel. Zkontroluj ho v Nastavení. (${base.message})');
  }
  if (lower.contains('location is not supported') ||
      (googleStatus == 'FAILED_PRECONDITION' && lower.contains('location'))) {
    return permanent(GeminiErrorKind.region, base.message);
  }
  if (status == 404) {
    return permanent(GeminiErrorKind.modelMissing, base.message);
  }
  if (status == 429) {
    return GeminiFailure(
      transient: true,
      message: base.message,
      kind: GeminiErrorKind.quota,
      statusCode: status,
      reason: reason,
    );
  }
  // Groq answers a per-minute token ceiling with 413; Google never does, and
  // a 413 from it means the request (usually a photo) really is too big.
  if (status == 413) {
    return permanent(GeminiErrorKind.badRequest, base.message);
  }
  if (status == 503 ||
      googleStatus == 'UNAVAILABLE' ||
      lower.contains('overloaded')) {
    return GeminiFailure(
      transient: true,
      message: base.message,
      kind: GeminiErrorKind.overloaded,
      statusCode: status,
      reason: reason,
    );
  }
  if (status != null && status >= 500) {
    return GeminiFailure(
      transient: true,
      message: base.message,
      kind: GeminiErrorKind.network,
      statusCode: status,
      reason: reason,
    );
  }
  return GeminiFailure(
    transient: base.transient,
    message: base.message,
    kind: GeminiErrorKind.badRequest,
    statusCode: status,
    reason: reason,
  );
}

/// Google's `{"error": {"status": ..., "message": ...}}` envelope.
({String? googleStatus, String? reason}) geminiErrorDetail(Object? body) {
  Object? data = body;
  if (data is String) {
    try {
      data = jsonDecode(data);
    } catch (_) {
      return (googleStatus: null, reason: null);
    }
  }
  final error = data is Map ? data['error'] : null;
  if (data is List && data.isNotEmpty && data.first is Map) {
    return geminiErrorDetail(data.first);
  }
  if (error is! Map) return (googleStatus: null, reason: null);
  final status = error['status'];
  final message = error['message'];
  return (
    googleStatus: status is String ? status : null,
    reason: message is String && message.trim().isNotEmpty
        ? clipReason(message.trim())
        : null,
  );
}

String clipReason(String value, {int max = 160}) =>
    value.length <= max ? value : '${value.substring(0, max)}…';

String _safeEncode(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return '$value';
  }
}
