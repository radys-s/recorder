import '../core/logging.dart';
import 'llm_provider.dart';

/// Runs [onGemini] when [preferGemini] is set, and [onRouter] when it is not
/// or when Gemini failed for any reason (rate limit, overload, retired model,
/// a refused key). Background jobs — digests, suggestions, study cards — never
/// need Gemini specifically, so a failure there must cost nothing.
///
/// [onRouter] runs the same request through the other services; its own failure
/// is the caller's to handle, exactly as if Gemini had never been tried.
Future<T> geminiFirst<T>({
  required bool preferGemini,
  required Future<T> Function() onGemini,
  required Future<T> Function() onRouter,
  String tag = 'ai.gemini_first',
}) async {
  if (preferGemini) {
    try {
      return await onGemini();
    } on AiException catch (e) {
      AppLog.w(
        tag,
        'Gemini failed (${e.statusCode ?? e.runtimeType}); '
        'using the other services',
      );
    }
  }
  return onRouter();
}
