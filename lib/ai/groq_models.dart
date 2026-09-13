import 'package:dio/dio.dart';

import '../core/groq_failure.dart';
import '../data/secure/api_key_store.dart';
import 'llm_provider.dart';

/// Lists the model ids this API key can actually use.
///
/// Groq retires models on short notice, and a retired — or simply
/// not-granted-to-this-key — id comes back as a 404 that the classifier
/// correctly parks as permanent, which reads like a bug in the app rather than
/// a wrong constant. Asking the account itself is the only reliable answer, and
/// it keeps the key on the device where it belongs.
Future<List<String>> listGroqModels(ApiKeyStore apiKeyStore, {Dio? dio}) async {
  final apiKey = await apiKeyStore.read();
  if (apiKey == null) {
    throw const AiPermanentException(
      'No Groq API key configured. Add one in Settings.',
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
      'https://api.groq.com/openai/v1/models',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );

    final data = response.data;
    final list = data is Map ? data['data'] : null;
    if (list is! List) {
      throw const AiPermanentException('Response carried no model list.');
    }

    final ids = <String>[
      for (final entry in list)
        if (entry is Map && entry['id'] is String) entry['id'] as String,
    ];
    ids.sort();
    return ids;
  } on DioException catch (e) {
    final failure = classifyGroqFailure(e);
    throw failure.transient
        ? AiTransientException(failure.message, statusCode: failure.statusCode)
        : AiPermanentException(failure.message, statusCode: failure.statusCode);
  }
}
