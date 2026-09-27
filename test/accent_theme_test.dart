import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/core/accent.dart';
import 'package:recorder/core/theme.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';

void main() {
  test('every preset has its own primary and carries the accent', () {
    final primaries = <Color>{};
    for (final preset in AccentPreset.values) {
      for (final b in Brightness.values) {
        final theme = appTheme(b, preset);
        final accent = theme.extension<AccentTheme>();
        expect(accent, isNotNull);
        expect(accent!.palette, AccentPalette.of(preset));
        primaries.add(theme.colorScheme.primary);
      }
    }
    expect(primaries, hasLength(AccentPreset.values.length * 2));
  });

  test('gold stays the default theme', () {
    expect(appLightTheme.colorScheme.primary, AccentPalette.gold.lightText);
    expect(appDarkTheme.colorScheme.primary, AccentPalette.gold.darkText);
  });

  test('accent text is readable on the surface it is drawn on', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final preset in AccentPreset.values) {
      final p = AccentPalette.of(preset);
      expect(
        contrast(p.lightText, Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: '${preset.name} on light',
      );
      expect(
        contrast(p.darkText, const Color(0xFF141416)),
        greaterThanOrEqualTo(4.5),
        reason: '${preset.name} on dark',
      );
      expect(
        contrast(p.onFill, p.fill),
        greaterThanOrEqualTo(3),
        reason: '${preset.name} ink on fill',
      );
    }
  });

  test('cards get a gradient outline', () {
    expect(
      appLightTheme.cardTheme.shape,
      isA<GradientRoundedRectangleBorder>(),
    );
  });

  testWidgets('context.accent falls back to gold without the app theme', (
    tester,
  ) async {
    late AccentTheme accent;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            accent = context.accent;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(accent.palette, AccentPalette.gold);
  });
}
