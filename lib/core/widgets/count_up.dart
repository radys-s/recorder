import 'package:flutter/material.dart';

import '../motion.dart';

/// A number that counts up to [value] when it first appears and glides to a new
/// value when it changes, instead of snapping.
///
/// Under reduced motion it shows [value] at once. The text is a plain [Text]
/// with tabular figures, so the width does not jitter while it runs; the
/// semantics label is the final number, so a screen reader never reads the
/// frames in between.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = AppDuration.slow,
    this.format,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  /// Turns the running number into text, e.g. adding a unit. Defaults to the
  /// plain number.
  final String Function(int value)? format;

  @override
  Widget build(BuildContext context) {
    final text = format ?? (int v) => '$v';
    final base = style ?? DefaultTextStyle.of(context).style;
    final tabular = base.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (reducedMotion(context)) return Text(text(value), style: tabular);

    return Semantics(
      label: text(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: value),
        duration: duration,
        curve: AppCurve.standard,
        builder: (_, current, _) => Text(text(current), style: tabular),
      ),
    );
  }
}
