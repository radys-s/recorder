import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../data/db/tables/transcript_segments_table.dart';
import '../../../queue/transcription_wait.dart';
import '../meeting_detail_providers.dart';
import '../../settings/settings_screen.dart';

/// Says why chunks are waiting when the cause is a limit or a missing key.
///
/// Without it the transcript just stops growing and a student has no way to
/// tell a slow network from a service that asked for a pause, or from a key
/// that was never saved.
class TranscriptionWaitNotice extends ConsumerWidget {
  const TranscriptionWaitNotice({super.key, this.meetingId});
  final int? meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wait = ref.watch(transcriptionWaitProvider).valueOrNull;
    final id = meetingId;
    final segments = id == null
        ? null
        : ref.watch(meetingSegmentsProvider(id)).valueOrNull;
    final pending =
        segments
            ?.where(
              (s) =>
                  s.status == SegmentStatus.pending ||
                  s.status == SegmentStatus.uploading,
            )
            .length ??
        0;
    // A global provider limit must not make a finished lesson look unfinished.
    if (id != null && pending == 0) return const SizedBox.shrink();
    if (wait == null && pending == 0) return const SizedBox.shrink();
    final missingKey = wait?.kind == TranscriptionWaitKind.missingKey;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
      child: Material(
        color: missingKey ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Gap.md),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    missingKey ? Icons.key_off_outlined : Icons.hourglass_empty,
                    size: 18,
                    color: missingKey
                        ? scheme.onErrorContainer
                        : scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      wait == null
                          ? 'Zvuk je uložený. Přepis čeká na zpracování $pending úseků; po připojení doběhne automaticky.'
                          : transcriptionWaitText(wait),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: missingKey
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (missingKey)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                  child: const Text('Otevřít nastavení'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
