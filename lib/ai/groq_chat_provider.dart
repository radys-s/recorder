import '../core/constants.dart';
import 'openai_compatible_provider.dart';

/// Groq's OpenAI-compatible chat completions endpoint — the preset of
/// [OpenAiCompatibleProvider] the app has used since M14.
class GroqChatProvider extends OpenAiCompatibleProvider {
  GroqChatProvider(super.apiKeyStore, {super.dio, super.reasoningEffort})
    : super(
        vendor: 'Groq',
        baseUrl: _base,
        missingKeyMessage: 'No Groq API key configured. Add one in Settings.',
      );

  static Future<String?> _base() async => kGroqBaseUrl;
}
