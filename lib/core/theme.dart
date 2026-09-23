// CupertinoPageTransitionsBuilder lives in cupertino/route.dart, not in
// material, so it needs this import even though nothing else here is
// Cupertino.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'spacing.dart';

/// The app's visual identity.
///
/// Titanium surfaces, ink typography and a glacial blue signal. The accent
/// names actions; recording and errors retain a separate, unmistakable red.
const _seed = Color(0xFF0B6A99);

abstract final class AftermindPalette {
  const AftermindPalette._();

  static const lightCanvas = Color(0xFFF4F6F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF18242C);
  static const lightMuted = Color(0xFF53636C);
  static const lightAccent = Color(0xFF0B6A99);
  static const lightAccentSoft = Color(0xFFDDF3FC);
  static const darkCanvas = Color(0xFF101418);
  static const darkSurface = Color(0xFF1B2228);
  static const darkInk = Color(0xFFEAF2F6);
  static const darkMuted = Color(0xFFB0BEC5);
  static const darkAccent = Color(0xFF85D8FF);
  static const darkAccentSoft = Color(0xFF123849);
  static const record = Color(0xFFB3261E);
  static const recordDark = Color(0xFFFFB4AB);
}

/// Digits that keep their width as they change. The recording clock and the
/// transcript timestamps both update every second; without this the text
/// reflows on every tick.
const kTabularFigures = <FontFeature>[FontFeature.tabularFigures()];

ThemeData get appLightTheme => _build(Brightness.light);
ThemeData get appDarkTheme => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness)
      .copyWith(
        primary: dark
            ? AftermindPalette.darkAccent
            : AftermindPalette.lightAccent,
        onPrimary: dark ? const Color(0xFF00354E) : Colors.white,
        primaryContainer: dark
            ? AftermindPalette.darkAccentSoft
            : AftermindPalette.lightAccentSoft,
        onPrimaryContainer: dark
            ? const Color(0xFFDDF3FC)
            : const Color(0xFF082B3D),
        secondary: dark ? const Color(0xFFB8CDD6) : const Color(0xFF45636F),
        onSecondary: dark ? const Color(0xFF20323A) : Colors.white,
        secondaryContainer: dark
            ? const Color(0xFF26363E)
            : const Color(0xFFE2EBEF),
        onSecondaryContainer: dark
            ? const Color(0xFFE0EDF2)
            : const Color(0xFF1B303A),
        surface: dark ? const Color(0xFF151A1E) : AftermindPalette.lightSurface,
        onSurface: dark ? AftermindPalette.darkInk : AftermindPalette.lightInk,
        surfaceContainerLowest: dark
            ? AftermindPalette.darkCanvas
            : AftermindPalette.lightCanvas,
        surfaceContainerLow: dark
            ? const Color(0xFF171D22)
            : const Color(0xFFF0F3F5),
        surfaceContainer: dark
            ? const Color(0xFF1B2228)
            : const Color(0xFFEBEFF2),
        surfaceContainerHigh: dark
            ? const Color(0xFF252E34)
            : const Color(0xFFE4E9EC),
        surfaceContainerHighest: dark
            ? const Color(0xFF303A41)
            : const Color(0xFFDCE3E7),
        onSurfaceVariant: dark
            ? AftermindPalette.darkMuted
            : AftermindPalette.lightMuted,
        outline: dark ? const Color(0xFF9BAAB2) : AftermindPalette.lightMuted,
        outlineVariant: dark
            ? const Color(0xFF46535A)
            : const Color(0xFFC5D0D5),
        error: dark ? AftermindPalette.recordDark : AftermindPalette.record,
      );

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
    // Three steps of depth on one hue: the page is the lowest surface, cards
    // sit one step up, sheets and dialogs one more. Hierarchy from tone, not
    // from shadows.
    scaffoldBackgroundColor: dark
        ? AftermindPalette.darkCanvas
        : AftermindPalette.lightCanvas,

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: scheme.surfaceTint,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      // Not zero: this is the only thing that separates a scrolled list from
      // the bar it is sliding under.
      scrolledUnderElevation: 3,
      centerTitle: false,
      // No titleTextStyle here: SliverAppBar.large prefers the theme's title
      // style over its own expanded headline, which shrank every large title
      // to toolbar size. The default is titleLarge, already w600 below.
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
        // A hairline in dark, where tone steps alone are too close to see.
        side: brightness == Brightness.dark
            ? BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))
            : BorderSide.none,
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
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.sm)),
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

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
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
      fillColor: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.lg),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.lg),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.lg),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Gap.md),
        ),
      ),
    ),

    // A quiet bar: the tint of the surface one step up rather than a coloured
    // band, with the pill behind the selected tab doing the pointing.
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.sheetRadius),
      ),
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outlineVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Gap.sheetRadius),
        ),
      ),
    ),

    chipTheme: ChipThemeData(
      labelStyle: text.labelLarge,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.sm),
      ),
      showCheckmark: false,
      selectedColor: scheme.secondaryContainer,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      textStyle: text.bodyLarge?.copyWith(color: scheme.onSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.md),
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
            : scheme.onSurfaceVariant,
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
/// Three things are being fixed: body text set slightly larger with a
/// generous line height, because a transcript is a wall of text people
/// actually read; titles at w600 rather than w400, so hierarchy comes from
/// weight instead of from more size steps; and the largest titles switch to
/// Bricolage Grotesque, a display face with more character than Inter at
/// heading size — Inter stays on everything actually read at length.
TextTheme _tuneText(TextTheme t) => t.copyWith(
  // Large collapsing titles on the root tabs: heavy and tight, the way a
  // native large title reads.
  headlineMedium: t.headlineMedium?.copyWith(
    fontFamily: 'BricolageGrotesque',
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  ),
  headlineSmall: t.headlineSmall?.copyWith(
    fontFamily: 'BricolageGrotesque',
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  ),
  titleLarge: t.titleLarge?.copyWith(
    fontFamily: 'BricolageGrotesque',
    fontWeight: FontWeight.w700,
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
