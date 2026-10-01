import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../queue/transcription_wait.dart';

/// Says why chunks are waiting when the cause is a limit or a missing key.
///
/// Without it the transcript just stops growing and a student has no way to
/// tell a slow network from a service that asked for a pause, or from a key
/// that was never saved.
class TranscriptionWaitNotice extends ConsumerWidget {
  const TranscriptionWaitNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wait = ref.watch(transcriptionWaitProvider).valueOrNull;
    if (wait == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: StatusChip(
          icon: wait.kind == TranscriptionWaitKind.missingKey
              ? Icons.key_off_outlined
              : Icons.hourglass_empty,
          label: transcriptionWaitText(wait),
          tone: wait.kind == TranscriptionWaitKind.missingKey
              ? ChipTone.alert
              : ChipTone.progress,
        ),
      ),
    );
  }
}
