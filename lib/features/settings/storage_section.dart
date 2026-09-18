import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/audio_cleaner.dart';
import '../../data/db/tables/preferences_table.dart';

/// What the lessons still on disk take up, biggest first. Read once per
/// visit: walking the directory is cheap, and a live stream of file sizes
/// would be a timer for something nobody watches change.
final audioSizesProvider = FutureProvider.autoDispose<List<MeetingAudioSize>>((
  ref,
) {
  return ref.watch(audioCleanerProvider).sizes();
});

/// „Místo na disku" — the only part of the app that grows without bound, and
/// the setting that decides how long it is kept.
class StorageSection extends ConsumerWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final retention = prefs.valueOrNull?.audioRetention;
    final sizes = ref.watch(audioSizesProvider);
    final total = sizes.valueOrNull?.fold<int>(0, (a, b) => a + b.bytes) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Místo na disku',
          description:
              'Nahrávka zabírá zhruba 2 MB za minutu. Přepis, výpisky i '
              'odpovědi zůstávají navždy — maže se jen zvuk, a až když ho '
              'nic nepotřebuje.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sd_storage_outlined),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        sizes.hasValue
                            ? 'Nahrávky zabírají ${formatBytes(total)}'
                            : 'Počítám…',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (sizes.valueOrNull?.isNotEmpty ?? false) ...[
                  const SizedBox(height: Gap.md),
                  for (final item in sizes.value!.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          Text(
                            formatBytes(item.bytes),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: Gap.md),
                Text(
                  'Uchovávat zvuk',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  children: [
                    for (final option in AudioRetention.ordered)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: retention == option,
                        onSelected: prefs.hasValue
                            ? (_) => ref
                                  .read(preferencesDaoProvider)
                                  .setAudioRetention(option)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: total == 0 ? null : () => _freeNow(context, ref),
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Uvolnit místo teď'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Waives the waiting, not the safety: a lesson whose chunks are still being
  /// uploaded or re-heard keeps its audio even here.
  Future<void> _freeNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final cleared = await ref.read(audioCleanerProvider).sweep(force: true);
    ref.invalidate(audioSizesProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          cleared == 0
              ? 'Není co uvolnit — zbylé nahrávky se ještě zpracovávají.'
              : 'Zvuk $cleared ${_lessonWord(cleared)} smazán.',
        ),
      ),
    );
  }

  static String _lessonWord(int count) => count == 1 ? 'hodiny' : 'hodin';
}
