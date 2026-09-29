import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/spacing.dart';

/// Before a recording starts without any transcription key: the audio would be
/// kept, but no text would appear until a key is saved. Says so and points to
/// Settings instead of letting the student find out an hour into the lesson.
///
/// [openSettings] is called when they choose to add a key; the recording is
/// then not started. True when the student goes on without one (the chunks
/// wait and are transcribed as soon as a key is saved).
Future<bool> confirmTranscriptionKey(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function() openSettings,
}) async {
  final groq = await ref.read(apiKeyStoreProvider).hasKey();
  final gemini = await ref.read(geminiKeyStoreProvider).hasKey();
  if (groq || gemini) return true;
  if (!context.mounted) return false;
  final choice = await showModalBottomSheet<_KeyChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _TranscriptionKeySheet(),
  );
  switch (choice) {
    case _KeyChoice.settings:
      await openSettings();
      return false;
    case _KeyChoice.record:
      return true;
    case null:
      return false;
  }
}

enum _KeyChoice { settings, record }

class _TranscriptionKeySheet extends StatelessWidget {
  const _TranscriptionKeySheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chybí klíč pro přepis', style: theme.textTheme.titleLarge),
            const SizedBox(height: Gap.md),
            Text(
              'Bez klíče Groq (nebo Gemini) se hodina nahraje, ale text se '
              'neobjeví. Přidej ho v Nastavení; přepis se pak doplní i '
              'zpětně.',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: Gap.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_KeyChoice.settings),
              child: const Text('Otevřít Nastavení'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_KeyChoice.record),
              child: const Text('Nahrávat i tak'),
            ),
          ],
        ),
      ),
    );
  }
}
