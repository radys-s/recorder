import 'dart:convert';

import 'package:dio/dio.dart';

import 'groq_failure.dart';

/// The retry decision for one failed Gemini request.
///
/// Transport failures and the 429/5xx split are the same as Groq's, so this
/// starts from [classifyGroqFailure] and only overrides what Google says
/// differently: an invalid key comes back as a **400** (`API_KEY_INVALID`),
/// not a 401, and the user has to be told which of the two keys is wrong.
GroqFailure classifyGeminiFailure(DioException e) {
  final base = classifyGroqFailure(e);
  if (e.type != DioExceptionType.badResponse) return base;

  final status = e.response?.statusCode;
  final body = e.response?.data;
  final raw = body is String ? body : _safeEncode(body);

  if ((status == 400 && raw.contains('API_KEY_INVALID')) ||
      status == 401 ||
      status == 403) {
    return GroqFailure(
      transient: false,
      message: 'Gemini klíč neprošel. Zkontroluj ho v Nastavení. '
          '(${base.message})',
      statusCode: status,
    );
  }
  // Groq answers a per-minute token ceiling with 413; Google never does, and
  // a 413 from it means the request (usually a photo) really is too big.
  if (status == 413) {
    return GroqFailure(
      transient: false,
      message: base.message,
      statusCode: status,
    );
  }
  return base;
}

String _safeEncode(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return '$value';
  }
}
