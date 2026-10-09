import 'package:flutter/material.dart';

import '../motion.dart';

/// Scales and fades [child] in with a small overshoot when it first appears.
///
/// For one-off "it worked" marks: a check after a right answer, the badge on a
/// finished session. Under reduced motion the child is simply there.
class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.child,
    this.duration = AppDuration.base,
    this.from = 0.4,
  });

  final Widget child;
  final Duration duration;

  /// Starting scale, 0–1.
  final double from;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutBack,
      child: child,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: from + (1 - from) * t, child: child),
      ),
    );
  }
}
