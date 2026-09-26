// CupertinoPageTransitionsBuilder lives in cupertino/route.dart, not in
// material, so it needs this import even though nothing else here is
// Cupertino.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'spacing.dart';

/// The app's visual identity.
///
/// Graphite surfaces, warm ink and a restrained gold. Gold names actions and
/// emphasis only; recording and errors keep their own unmistakable red, so
/// "this is live" never reads as "this is a button".
///
/// Every colour the app paints lives here. Tune the identity in this class,
/// not in widgets.
const _seed = Color(0xFFB8913F);

abstract final class AftermindPalette {
  const AftermindPalette._();

  // Light: an iOS-like grouped background, white groups, near-black ink.
  static const lightCanvas = Color(0xFFF2F1EE);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF161618);
  static const lightMuted = Color(0xFF6C6C71);
  // Dark enough to carry white text and read as gold, not brown.
  static const lightGold = Color(0xFF8F6619);

  // Dark: near-black, never pure black, so the gold has something to glow on.
  static const darkCanvas = Color(0xFF0B0B0D);
  static const darkSurface = Color(0xFF141416);
  static const darkCard = Color(0xFF1B1B1E);
  static const darkInk = Color(0xFFF3F1EC);
  static const darkMuted = Color(0xFFA3A19B);
  static const darkGold = Color(0xFFE2B55E);

  /// The brand gold as a fill: the record disc, the icon, glows. Never text.
  static const gold = Color(0xFFC9973A);
  static const graphite = Color(0xFF1C1D21);

  /// The dashboard stage: dark in both themes, so the gold disc and the red
  /// recording state always sit on the same ground.
  static const stage = Color(0xFF151619);
  static const stageDark = Color(0xFF18191C);
  static const stageInk = Color(0xFFF4F2ED);

  static const record = Color(0xFFD93B30);
  static const recordDark = Color(0xFFFF5F55);
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
        primary: dark ? AftermindPalette.darkGold : AftermindPalette.lightGold,
        onPrimary: dark ? const Color(0xFF2A1F08) : Colors.white,
        // Neutral, not beige: a filled container carries gold only in its
        // icon and label, so gold keeps meaning "this is the action".
        primaryContainer: dark ? const Color(0xFF2A2A2E) : const Color(0xFFE9E7E2),
        onPrimaryContainer: dark
            ? AftermindPalette.darkGold
            : const Color(0xFF6E4E12),
        // Secondary is graphite, not a second hue: selected chips, segments
        // and quiet containers stay neutral so gold keeps meaning "act".
        secondary: dark ? const Color(0xFFBDBEC4) : const Color(0xFF55575D),
        onSecondary: dark ? const Color(0xFF1F2024) : Colors.white,
        secondaryContainer: dark
            ? const Color(0xFF2B2D32)
            : const Color(0xFFE7E4DD),
        onSecondaryContainer: dark
            ? const Color(0xFFE6E4DF)
            : const Color(0xFF1F2023),
        tertiary: dark ? const Color(0xFFE9D3A2) : const Color(0xFF6E5A33),
        onTertiary: dark ? const Color(0xFF2A1F08) : Colors.white,
        tertiaryContainer: dark
            ? const Color(0xFF33302A)
            : const Color(0xFFF0E8D8),
        onTertiaryContainer: dark
            ? const Color(0xFFF1E6CF)
            : const Color(0xFF2B2415),
        surface: dark ? AftermindPalette.darkSurface : AftermindPalette.lightSurface,
        onSurface: dark ? AftermindPalette.darkInk : AftermindPalette.lightInk,
        surfaceContainerLowest: dark
            ? AftermindPalette.darkCanvas
            : AftermindPalette.lightCanvas,
        surfaceContainerLow: dark
            ? AftermindPalette.darkCard
            : AftermindPalette.lightCard,
        surfaceContainer: dark
            ? const Color(0xFF202125)
            : const Color(0xFFF0EDE7),
        surfaceContainerHigh: dark
            ? const Color(0xFF26282C)
            : const Color(0xFFEAE7E0),
        surfaceContainerHighest: dark
            ? const Color(0xFF303237)
            : const Color(0xFFE1DDD4),
        onSurfaceVariant: dark
            ? AftermindPalette.darkMuted
            : AftermindPalette.lightMuted,
        outline: dark ? const Color(0xFF8D8A84) : const Color(0xFF7A776F),
        outlineVariant: dark
            ? const Color(0xFF3A3B40)
            : const Color(0xFFD9D4CA),
        inverseSurface: dark ? const Color(0xFFEEEAE2) : const Color(0xFF26272B),
        onInverseSurface: dark ? const Color(0xFF1B1C1F) : const Color(0xFFF1EEE8),
        inversePrimary: dark ? AftermindPalette.lightGold : AftermindPalette.darkGold,
        surfaceTint: Colors.transparent,
        error: dark ? AftermindPalette.recordDark : AftermindPalette.record,
        onError: dark ? const Color(0xFF3B0907) : Colors.white,
        errorContainer: dark ? const Color(0xFF4A1512) : const Color(0xFFFBDDD9),
        onErrorContainer: dark ? const Color(0xFFFFDAD5) : const Color(0xFF410E0B),
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
      surfaceTintColor: scheme.onSurface,
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
        // A hairline in both themes: graphite tone steps are deliberately close.
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: dark ? 0.55 : 0.7),
        ),
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
