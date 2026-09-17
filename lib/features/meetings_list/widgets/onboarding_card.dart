import 'package:flutter/material.dart';

import '../../../core/spacing.dart';

enum OnboardingStep { groqKey, geminiKey, subject, timetable }

typedef OnboardingItem = ({OnboardingStep step, bool done, bool optional});

/// The first-run checklist, ticked off from what the app already knows.
/// Only the Groq key and a first subject are required: without the key
/// nothing is transcribed, without a subject the class assistant is idle.
List<OnboardingItem> onboardingSteps({
  required bool hasGroqKey,
  required bool hasGeminiKey,
  required bool hasSubject,
  required bool hasTimetable,
}) => [
  (step: OnboardingStep.groqKey, done: hasGroqKey, optional: false),
  (step: OnboardingStep.geminiKey, done: hasGeminiKey, optional: true),
  (step: OnboardingStep.subject, done: hasSubject, optional: false),
  (step: OnboardingStep.timetable, done: hasTimetable, optional: true),
];

bool onboardingRequiredDone(List<OnboardingItem> steps) =>
    steps.every((s) => s.optional || s.done);

({String title, String subtitle, IconData icon}) _copy(OnboardingStep step) =>
    switch (step) {
      OnboardingStep.groqKey => (
        title: 'Vlož Groq klíč',
        subtitle: 'Bez něj se nahrávka nepřepíše.',
        icon: Icons.key,
      ),
      OnboardingStep.geminiKey => (
        title: 'Přidej Gemini klíč',
        subtitle: 'Fotky tabule, dohledání knih a chytřejší odpovědi.',
        icon: Icons.auto_awesome,
      ),
      OnboardingStep.subject => (
        title: 'Založ první předmět',
        subtitle: 'Třeba Čeština — AI pak ví, o čem hodina je.',
        icon: Icons.school_outlined,
      ),
      OnboardingStep.timetable => (
        title: 'Vyplň rozvrh',
        subtitle: 'Předmět se při nahrávání vybere sám.',
        icon: Icons.schedule,
      ),
    };

/// „Začínáme" above the record button on Nahrávky.
class OnboardingCard extends StatelessWidget {
  const OnboardingCard({
    super.key,
    required this.steps,
    required this.onStep,
    required this.onClose,
  });

  final List<OnboardingItem> steps;
  final ValueChanged<OnboardingStep> onStep;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = steps.where((s) => s.done).length;
    final ready = onboardingRequiredDone(steps);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xs),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Gap.radius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ready ? 'Hotovo, můžeš nahrávat' : 'Začínáme',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '$done ze ${steps.length} kroků',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onClose,
                    child: Text(ready ? 'Zavřít' : 'Skrýt'),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: done / steps.length,
                  minHeight: 4,
                  semanticsLabel: 'Průvodce, $done ze ${steps.length} kroků',
                ),
              ),
              const SizedBox(height: Gap.xs),
              for (final item in steps) _StepRow(item: item, onTap: onStep),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.item, required this.onTap});

  final OnboardingItem item;
  final ValueChanged<OnboardingStep> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final copy = _copy(item.step);

    return ListTile(
      contentPadding: const EdgeInsets.only(right: Gap.sm),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: item.done
            ? scheme.primary
            : scheme.surfaceContainerHighest,
        child: Icon(
          item.done ? Icons.check : copy.icon,
          size: 18,
          color: item.done ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        copy.title,
        style: item.done
            ? TextStyle(
                color: scheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      subtitle: Text(
        item.optional && !item.done
            ? '${copy.subtitle} Nepovinné.'
            : copy.subtitle,
      ),
      trailing: item.done ? null : const Icon(Icons.chevron_right),
      onTap: item.done ? null : () => onTap(item.step),
    );
  }
}
