import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/db/tables/preferences_table.dart';
import '../subjects/subjects_providers.dart';

/// „Připomínka hodiny" — the phone says a timetabled lesson is about to start.
///
/// Turning it on is where notification permission is asked for, because that
/// is the only moment the request can explain itself.
class LessonRemindersSection extends ConsumerWidget {
  const LessonRemindersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final current = prefs.valueOrNull?.lessonReminder;
    final slots = ref.watch(allSlotsProvider).valueOrNull;
    final hasTimetable = slots != null && slots.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Připomínka hodiny',
          description:
              'Podle rozvrhu upozorní, že za chvíli začíná hodina, ať se '
              'nahrávání nezapomene zapnout.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Gap.sm,
                  children: [
                    for (final option in LessonReminder.ordered)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: current == option,
                        onSelected: prefs.hasValue
                            ? (_) => _choose(context, ref, option)
                            : null,
                      ),
                  ],
                ),
                if (!hasTimetable) ...[
                  const SizedBox(height: Gap.md),
                  Text(
                    'Zatím není co připomínat — přidej hodiny do rozvrhu '
                    'u předmětu.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    LessonReminder option,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(lessonReminderServiceProvider)
        .setReminder(option);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Bez povolení upozornění to nepůjde — zapni je v nastavení '
            'telefonu.',
          ),
        ),
      );
    }
  }
}
