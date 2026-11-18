import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';
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
    final failed = [
      for (final s in segments ?? const <TranscriptSegment>[])
        if (s.status == SegmentStatus.failed) s.id,
    ];
    final pending =
        segments
            ?.where(
              (s) =>
                  s.status == SegmentStatus.pending ||
                  s.status == SegmentStatus.uploading,
            )
            .length ??
        0;
    // Parked chunks are retried here in one tap; their rows only mark where
    // the gaps are.
    if (failed.isNotEmpty && pending == 0) {
      return _FailedNotice(
        count: failed.length,
        onRetry: () => ref.read(queueWorkerProvider).retrySegments(failed),
      );
    }
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

/// Chunks the queue gave up on. The audio is on disk, so one tap puts all of
/// them back in line; if that fails again the key is the usual cause.
class _FailedNotice extends StatelessWidget {
  const _FailedNotice({required this.count, required this.onRetry});

  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // „Se nepodařilo přepsat" takes the accusative: 1 úsek, 2–4 úseky, 5+ úseků.
    final chunks = switch (count) {
      1 => '1 úsek',
      2 || 3 || 4 => '$count úseky',
      _ => '$count úseků',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
      child: Material(
        color: scheme.errorContainer,
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
                    Icons.error_outline,
                    size: 18,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      '$chunks se nepodařilo přepsat. Zvuk je uložený. Když to nepomůže '
                      'ani napodruhé, zkontroluj klíč v Nastavení.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Zkusit znovu vše'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
