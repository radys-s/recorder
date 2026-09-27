import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/db/tables/preferences_table.dart';

/// One accent colour family: the student picks it in Settings, and every
/// gradient in the app is built from these five tones.
///
/// [fill] is the brand colour as a surface (record disc, selected pill);
/// [highlight] and [deep] are its light and dark ends, so a gradient across
/// them reads as one lit object rather than two colours; [partner] is a
/// neighbouring hue that gives outlines their colour shift.
@immutable
class AccentPalette {
  const AccentPalette({
    required this.fill,
    required this.highlight,
    required this.deep,
    required this.partner,
    required this.lightText,
    required this.darkText,
    required this.onFill,
    required this.lightContainerText,
  });

  final Color fill;
  final Color highlight;
  final Color deep;
  final Color partner;

  /// Accent as text or an icon on a light surface (≥ 4.5:1 on white).
  final Color lightText;

  /// Accent as text or an icon on a dark surface.
  final Color darkText;

  /// Ink on top of [fill].
  final Color onFill;
  final Color lightContainerText;

  static const gold = AccentPalette(
    fill: Color(0xFFC9973A),
    highlight: Color(0xFFF0CB7A),
    deep: Color(0xFF9C6D1E),
    partner: Color(0xFFE08A5B),
    lightText: Color(0xFF8F6619),
    darkText: Color(0xFFE2B55E),
    onFill: Color(0xFF2A1F08),
    lightContainerText: Color(0xFF6E4E12),
  );

  static const sapphire = AccentPalette(
    fill: Color(0xFF3D7BE0),
    highlight: Color(0xFF7FB2FF),
    deep: Color(0xFF2450B0),
    partner: Color(0xFF5AC8E8),
    lightText: Color(0xFF2459B8),
    darkText: Color(0xFF8AB6FF),
    onFill: Colors.white,
    lightContainerText: Color(0xFF1D4690),
  );

  static const emerald = AccentPalette(
    fill: Color(0xFF25A57A),
    highlight: Color(0xFF6EE0B0),
    deep: Color(0xFF157556),
    partner: Color(0xFF3CC4C0),
    lightText: Color(0xFF11785A),
    darkText: Color(0xFF5FD3A6),
    onFill: Color(0xFF06281C),
    lightContainerText: Color(0xFF0E5E47),
  );

  static const amethyst = AccentPalette(
    fill: Color(0xFF8B5CF6),
    highlight: Color(0xFFC0A2FF),
    deep: Color(0xFF6236D0),
    partner: Color(0xFFE36FC4),
    lightText: Color(0xFF6B3FD4),
    darkText: Color(0xFFB79CFF),
    onFill: Colors.white,
    lightContainerText: Color(0xFF4F2CA6),
  );

  static AccentPalette of(AccentPreset preset) => switch (preset) {
    AccentPreset.gold => gold,
    AccentPreset.sapphire => sapphire,
    AccentPreset.emerald => emerald,
    AccentPreset.amethyst => amethyst,
  };
}

/// The accent's gradients, carried on the theme so widgets never pick a
/// colour of their own: `context.accent.fillGradient`.
@immutable
class AccentTheme extends ThemeExtension<AccentTheme> {
  const AccentTheme({required this.palette, required this.brightness});

  final AccentPalette palette;
  final Brightness brightness;

  bool get _dark => brightness == Brightness.dark;

  Color get fill => palette.fill;
  Color get highlight => palette.highlight;
  Color get deep => palette.deep;
  Color get partner => palette.partner;
  Color get onFill => palette.onFill;

  /// The accent as text on the current surface.
  Color get text => _dark ? palette.darkText : palette.lightText;

  /// A lit, solid accent surface: buttons, the record disc, selected marks.
  LinearGradient get fillGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [palette.highlight, palette.fill, palette.deep],
    stops: const [0, 0.5, 1],
  );

  /// A bright line that shifts hue along its length: focused and selected
  /// outlines.
  LinearGradient outlineGradient({double opacity = 1}) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      palette.partner.withValues(alpha: opacity),
      palette.fill.withValues(alpha: opacity),
      palette.highlight.withValues(alpha: opacity),
    ],
  );

  /// The quiet outline of every group and card: accent at one corner fading
  /// into the neutral hairline, so the whole app shares one light source.
  LinearGradient hairline(Color neutral) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      palette.highlight.withValues(alpha: _dark ? 0.55 : 0.75),
      neutral,
      neutral,
      palette.partner.withValues(alpha: _dark ? 0.30 : 0.40),
    ],
    stops: const [0, 0.38, 0.72, 1],
  );

  /// A ring that travels all the way around: the record disc, avatars.
  SweepGradient get ring => SweepGradient(
    colors: [
      palette.highlight,
      palette.fill,
      palette.partner,
      palette.deep,
      palette.highlight,
    ],
  );

  /// A tint for surfaces that carry the accent without shouting: the
  /// selected dock pill, a selected chip, an icon tile.
  LinearGradient softGradient({double strength = 1}) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      palette.highlight.withValues(alpha: (_dark ? 0.26 : 0.30) * strength),
      palette.partner.withValues(alpha: (_dark ? 0.10 : 0.12) * strength),
    ],
  );

  /// Text or icons painted with the accent: light end to readable end.
  LinearGradient get textGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _dark
        ? [palette.highlight, palette.darkText]
        : [palette.fill, palette.lightText],
  );

  @override
  AccentTheme copyWith({AccentPalette? palette, Brightness? brightness}) =>
      AccentTheme(
        palette: palette ?? this.palette,
        brightness: brightness ?? this.brightness,
      );

  @override
  AccentTheme lerp(covariant AccentTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AccentContext on BuildContext {
  /// The current accent. Falls back to gold when a test builds a bare
  /// MaterialApp without the app's theme.
  AccentTheme get accent {
    final theme = Theme.of(this);
    return theme.extension<AccentTheme>() ??
        AccentTheme(palette: AccentPalette.gold, brightness: theme.brightness);
  }
}

/// A two-colour gradient between a subject's colour and a lighter, slightly
/// shifted tone of it — subject dots, tiles and icon boxes.
LinearGradient subjectGradient(Color color) {
  final hsl = HSLColor.fromColor(color);
  final light = hsl
      .withLightness((hsl.lightness + 0.16).clamp(0.0, 0.92))
      .withHue((hsl.hue + 18) % 360)
      .toColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [light, color],
  );
}

/// A rounded rectangle whose outline is a gradient instead of one colour.
///
/// A real [OutlinedBorder], so it works anywhere a shape does — the card
/// theme, chips, buttons — and every card in the app gets the same lit edge.
class GradientRoundedRectangleBorder extends RoundedRectangleBorder {
  const GradientRoundedRectangleBorder({
    required this.gradient,
    super.borderRadius,
    this.width = 1,
  }) : super(side: BorderSide.none);

  final Gradient gradient;
  final double width;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  GradientRoundedRectangleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) => GradientRoundedRectangleBorder(
    gradient: gradient,
    borderRadius: borderRadius ?? this.borderRadius,
    width: width,
  );

  @override
  GradientRoundedRectangleBorder scale(double t) =>
      GradientRoundedRectangleBorder(
        gradient: gradient,
        borderRadius: borderRadius * t,
        width: width * t,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is GradientRoundedRectangleBorder
      ? GradientRoundedRectangleBorder(
          gradient: Gradient.lerp(a.gradient, gradient, t) ?? gradient,
          borderRadius: BorderRadiusGeometry.lerp(
            a.borderRadius,
            borderRadius,
            t,
          )!,
          width: ui.lerpDouble(a.width, width, t)!,
        )
      : (t < 0.5 ? a : this);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is GradientRoundedRectangleBorder
      ? b.lerpFrom(this, t)
      : (t < 0.5 ? this : b);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (width <= 0) return;
    final rrect = borderRadius
        .resolve(textDirection)
        .toRRect(rect)
        .deflate(width / 2);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = gradient.createShader(rect, textDirection: textDirection),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GradientRoundedRectangleBorder &&
      other.gradient == gradient &&
      other.borderRadius == borderRadius &&
      other.width == width;

  @override
  int get hashCode => Object.hash(gradient, borderRadius, width);
}

/// Paints a gradient outline over [child], following [borderRadius] (or a
/// circle). For surfaces that are not Cards: groups, the dock, tiles.
class GradientOutline extends StatelessWidget {
  const GradientOutline({
    super.key,
    required this.gradient,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.width = 1,
    this.circle = false,
  });

  final Gradient gradient;
  final Widget child;
  final BorderRadius borderRadius;
  final double width;
  final bool circle;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _OutlinePainter(gradient, borderRadius, width, circle),
    child: child,
  );
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.gradient, this.radius, this.width, this.circle);

  final Gradient gradient;
  final BorderRadius radius;
  final double width;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = gradient.createShader(rect);
    final inner = rect.deflate(width / 2);
    if (circle) {
      canvas.drawOval(inner, paint);
    } else {
      canvas.drawRRect(radius.toRRect(rect).deflate(width / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.gradient != gradient ||
      old.radius != radius ||
      old.width != width ||
      old.circle != circle;
}

/// Paints [child] (an icon or text) with [gradient] instead of a flat colour.
class GradientMask extends StatelessWidget {
  const GradientMask({super.key, required this.gradient, required this.child});

  final Gradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: gradient.createShader,
    child: child,
  );
}
