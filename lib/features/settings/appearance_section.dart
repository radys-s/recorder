import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/db/tables/preferences_table.dart';

/// Settings → Vzhled: the accent colour the whole app is lit with.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key, this.first = false});

  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final selected = prefs.valueOrNull?.accentPreset ?? AccentPreset.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          first: first,
          title: 'Vzhled',
          description:
              'Barva, ve které svítí tlačítko nahrávání, obrysy a výběry '
              'v celé aplikaci.',
        ),
        Row(
          children: [
            for (final preset in AccentPreset.values) ...[
              if (preset.index > 0) const SizedBox(width: Gap.sm),
              Expanded(
                child: _Swatch(
                  preset: preset,
                  selected: preset == selected,
                  onTap: prefs.hasValue
                      ? () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(preferencesDaoProvider)
                              .setAccentPreset(preset);
                        }
                      : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.preset, required this.selected, this.onTap});

  final AccentPreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = AccentPalette.of(preset);
    final accent = AccentTheme(palette: palette, brightness: theme.brightness);
    final radius = BorderRadius.circular(Gap.lg);
    final duration = reducedMotion(context) ? Duration.zero : AppDuration.quick;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Barva ${preset.label}',
      enabled: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: AppCurve.standard,
          padding: const EdgeInsets.fromLTRB(
            Gap.sm,
            Gap.md,
            Gap.sm,
            Gap.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: scheme.surfaceContainerLow,
            gradient: selected ? accent.softGradient(strength: 0.8) : null,
            border: selected
                ? null
                : Border.all(color: scheme.outlineVariant, width: 0.8),
          ),
          foregroundDecoration: selected
              ? ShapeDecoration(
                  shape: GradientRoundedRectangleBorder(
                    borderRadius: radius,
                    gradient: accent.outlineGradient(),
                    width: 1.6,
                  ),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1 : 0.88,
                duration: duration,
                curve: AppCurve.standard,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: accent.fillGradient,
                    boxShadow: [
                      BoxShadow(
                        color: palette.fill.withValues(
                          alpha: selected ? 0.5 : 0.2,
                        ),
                        blurRadius: selected ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 22,
                          color: palette.onFill,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: Gap.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  preset.label,
                  maxLines: 1,
                  softWrap: false,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? accent.text : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
