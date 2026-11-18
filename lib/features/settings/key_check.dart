import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/gemini_models.dart';
import '../../ai/groq_models.dart';
import '../../ai/llm_provider.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/redaction.dart';

/// Lists the models the saved Groq key can use. A provider so the key card can
/// be tested without a network.
final groqModelListerProvider = Provider<Future<List<String>> Function()>(
  (ref) =>
      () => listGroqModels(ref.read(apiKeyStoreProvider)),
);

/// Lists the models the saved Gemini key can use. Free, unlike the full
/// „Ověřit klíč" test, which spends two small requests.
final geminiModelListerProvider = Provider<Future<List<String>> Function()>(
  (ref) =>
      () => listGeminiModels(ref.read(geminiKeyStoreProvider)),
);

/// Tells the transcription queue that a key was saved or removed, so chunks
/// waiting for one move at once. A provider so the key cards can be tested
/// without a database.
final keysChangedProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => ref.read(queueWorkerProvider).keysChanged(),
);

/// What a key check found, in the words the key card shows.
class KeyCheck {
  const KeyCheck(this.works, this.message);

  /// True when the service accepted the key, false when it refused it, null
  /// when it could not be asked (offline, busy).
  final bool? works;
  final String message;
}

/// Asks the service whether the key works, so a typo or an expired key is
/// found when it is saved, not an hour into the next lesson.
///
/// With [needsTranscription] the check also says whether the key can reach a
/// Whisper model.
Future<KeyCheck> checkKey(
  String service,
  Future<List<String>> Function() listModels, {
  bool needsTranscription = false,
}) async {
  try {
    final ids = await listModels();
    if (!needsTranscription) return const KeyCheck(true, 'Klíč funguje.');
    final hasWhisper =
        ids.contains(kGroqWhisperModel) || ids.contains(kGroqWhisperTurboModel);
    return KeyCheck(
      true,
      hasWhisper
          ? 'Klíč funguje · přepis je dostupný.'
          : 'Klíč funguje, ale přepisovací model tam chybí — aplikace zkusí '
                'záložní.',
    );
  } on AiTransientException {
    return const KeyCheck(
      null,
      'Klíč je uložený, ale teď ho nejde ověřit. Zkontroluj připojení '
      'a klepni na Ověřit klíč.',
    );
  } on AiException catch (e) {
    final status = e.statusCode;
    if (status == 400 || status == 401 || status == 403) {
      return KeyCheck(
        false,
        'Klíč nefunguje — $service ho odmítl. Zkopíruj ho znovu celý '
        'a ulož.',
      );
    }
    return KeyCheck(false, 'Klíč nefunguje: ${redactSecrets(e.message)}');
  } catch (_) {
    return const KeyCheck(
      null,
      'Klíč je uložený, ale teď ho nejde ověřit. Zkontroluj připojení '
      'a klepni na Ověřit klíč.',
    );
  }
}

/// The snackbar after saving: one sentence that says whether the student is
/// done.
String savedKeyMessage(KeyCheck check) => switch (check.works) {
  true => 'Klíč uložen a funguje.',
  false => 'Klíč uložen, ale nefunguje. Podrobnosti jsou u klíče.',
  null => 'Klíč uložen. Ověřit ho teď nejde — zkontroluj připojení.',
};
