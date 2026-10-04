import 'package:flutter/material.dart';

import '../../../core/accent.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/inset_group.dart';

enum OnboardingStep { groqKey, geminiKey, subject, study, timetable }

typedef OnboardingItem = ({OnboardingStep step, bool done, bool optional});

/// The first-run checklist, ticked off from what the app already knows.
/// A transcription key and a first subject are required: without a key
/// nothing is transcribed, without a subject the class assistant is idle.
List<OnboardingItem> onboardingSteps({
  required bool hasGroqKey,
  required bool hasGeminiKey,
  required bool hasSubject,
  required bool hasStudyProfile,
  required bool hasTimetable,
}) => [
  (
    step: OnboardingStep.groqKey,
    done: hasGroqKey || hasGeminiKey,
    optional: false,
  ),
  (step: OnboardingStep.geminiKey, done: hasGeminiKey, optional: true),
  (step: OnboardingStep.subject, done: hasSubject, optional: false),
  (step: OnboardingStep.study, done: hasStudyProfile, optional: true),
  (step: OnboardingStep.timetable, done: hasTimetable, optional: true),
];

/// Czech voices the preposition before 4: 'ze 4' but 'z 5'.
String _of(int n) => n == 4 ? 'ze $n' : 'z $n';

bool onboardingRequiredDone(List<OnboardingItem> steps) =>
    steps.every((s) => s.optional || s.done);

({String title, String subtitle, IconData icon}) _copy(OnboardingStep step) =>
    switch (step) {
      OnboardingStep.groqKey => (
        title: 'Připoj přepis',
        subtitle: 'Vlož vlastní klíč Groq nebo Gemini v Nastavení.',
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
      OnboardingStep.study => (
        title: 'Škola a ročník',
        subtitle: 'AI pak odpovídá na tvé úrovni a zná tematický plán.',
        icon: Icons.menu_book_outlined,
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
      // Same surface and hairline as the inset groups below it, so the guide
      // reads as part of the page rather than as a slab dropped on top.
      child: GradientOutline(
        gradient: context.accent.hairline(
          scheme.outlineVariant.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.5 : 0.65,
          ),
        ),
        borderRadius: BorderRadius.circular(InsetGroup.radius),
        width: 0.8,
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(InsetGroup.radius),
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
                            '$done ${_of(steps.length)} kroků',
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
                Semantics(
                  label: 'Průvodce, $done ${_of(steps.length)} kroků',
                  child: _GradientProgress(value: done / steps.length),
                ),
                const SizedBox(height: Gap.xs),
                for (final item in steps) _StepRow(item: item, onTap: onStep),
              ],
            ),
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
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: item.done ? context.accent.fillGradient : null,
          color: item.done ? null : scheme.surfaceContainerHighest,
        ),
        child: Icon(
          item.done ? Icons.check : copy.icon,
          size: 18,
          color: item.done ? context.accent.onFill : scheme.onSurfaceVariant,
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

/// A thin track filled with the accent gradient up to [value].
class _GradientProgress extends StatelessWidget {
  const _GradientProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: scheme.surfaceContainerHighest),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: context.accent.fillGradient,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
