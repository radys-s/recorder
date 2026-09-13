// CupertinoPageTransitionsBuilder lives in cupertino/route.dart, not in
// material, so it needs this import even though nothing else here is
// Cupertino.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'spacing.dart';

/// The app's visual identity.
///
/// Slate blue, deliberately restrained: the one thing that must always be the
/// most salient element on screen is the red recording state, and a loud brand
/// colour would compete with it. Everything else — cards, app bars, list rows —
/// is defined once here rather than styled per widget, which is what keeps two
/// screens from quietly drifting apart.
const _seed = Color(0xFF38547A);

/// Digits that keep their width as they change. The recording clock and the
/// transcript timestamps both update every second; without this the text
/// reflows on every tick.
const kTabularFigures = <FontFeature>[FontFeature.tabularFigures()];

ThemeData get appLightTheme => _build(Brightness.light);
ThemeData get appDarkTheme => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

  // fontFamily at construction time so the family reaches every default text
  // style; the tuning below then only touches size, weight and line height.
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: 'Inter',
    visualDensity: VisualDensity.standard,
  );
  final text = _tuneText(base.textTheme);

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      // Not zero: this is the only thing that separates a scrolled list from
      // the bar it is sliding under.
      scrolledUnderElevation: 3,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Flat cards with a tinted surface rather than a shadow. Elevation was
    // previously set per widget — 0 on the answer card, default on the notes
    // error — so the same kind of surface looked like two different things.
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.radius),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.xs,
      ),
      titleTextStyle: text.bodyLarge?.copyWith(color: scheme.onSurface),
      subtitleTextStyle: text.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      iconColor: scheme.onSurfaceVariant,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: text.titleSmall,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: scheme.outlineVariant,
      overlayColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: 0.06),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Gap.sm),
          ),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Gap.md),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Gap.sm),
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 2,
      focusElevation: 3,
      hoverElevation: 3,
      highlightElevation: 4,
      extendedTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.lg),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.md),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.md),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.outline,
      ),
    ),

    // Cupertino's edge-swipe-back on iOS, because that is the gesture the
    // platform trains people to expect; a fade-forwards on Android, which is
    // the current Material spec and much calmer than the old zoom.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Sizes and weights on top of Material's defaults.
///
/// Two things are being fixed: body text set slightly larger with a generous
/// line height, because a transcript is a wall of text people actually read;
/// and titles at w600 rather than w400, so hierarchy comes from weight instead
/// of from more size steps.
TextTheme _tuneText(TextTheme t) => t.copyWith(
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.4),
      bodySmall: t.bodySmall?.copyWith(height: 1.35),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: t.labelSmall?.copyWith(letterSpacing: 0.3),
    );
