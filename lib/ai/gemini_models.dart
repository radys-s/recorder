import 'package:dio/dio.dart';

import '../core/constants.dart';
import '../core/gemini_failure.dart';
import '../data/secure/api_key_store.dart';
import 'llm_provider.dart';

/// The Gemini model ids this key can generate content with.
///
/// This is what „Ověřit klíč" calls: a bad key fails here with the same
/// classified error a real request would, and a model id that has been
/// retired shows up as missing from the list rather than as a mysterious 404
/// in the middle of a lesson.
Future<List<String>> listGeminiModels(
  ApiKeyStore apiKeyStore, {
  Dio? dio,
}) async {
  final apiKey = await apiKeyStore.read();
  if (apiKey == null) {
    throw const AiPermanentException(
      'Chybí Gemini klíč. Přidej ho v Nastavení.',
    );
  }

  final client = dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          responseType: ResponseType.json,
        ),
      );

  try {
    final response = await client.get<Object?>(
      '$kGeminiBaseUrl/models',
      queryParameters: {'pageSize': 1000},
      options: Options(headers: {'x-goog-api-key': apiKey}),
    );

    final data = response.data;
    final list = data is Map ? data['models'] : null;
    if (list is! List) {
      throw const AiPermanentException('Response carried no model list.');
    }

    final ids = <String>{
      for (final entry in list)
        if (entry is Map && entry['name'] is String && _generates(entry))
          (entry['name'] as String).replaceFirst('models/', ''),
    }.toList()
      ..sort();
    return ids;
  } on DioException catch (e) {
    final failure = classifyGeminiFailure(e);
    throw failure.transient
        ? AiTransientException(failure.message, statusCode: failure.statusCode)
        : AiPermanentException(failure.message, statusCode: failure.statusCode);
  }
}

/// Embedding-only models cannot answer anything; a model that does not say
/// what it supports is kept rather than hidden.
bool _generates(Map<Object?, Object?> entry) {
  final methods = entry['supportedGenerationMethods'];
  return methods is! List || methods.contains('generateContent');
}
