import 'package:flutter/material.dart';

import 'motion.dart';

/// Keeps MaterialPageRoute's lifecycle and iOS interactive back gesture.
/// Elsewhere pages enter with the same fade and 24 logical-pixel lift.
class AppRoute<T> extends MaterialPageRoute<T> {
  AppRoute({required super.builder, super.settings, super.fullscreenDialog});

  bool get _nativeIos =>
      navigator != null &&
      Theme.of(navigator!.context).platform == TargetPlatform.iOS;

  @override
  Duration get transitionDuration =>
      _nativeIos ? super.transitionDuration : AppDuration.quick;

  @override
  Duration get reverseTransitionDuration =>
      _nativeIos ? super.reverseTransitionDuration : AppDuration.quick;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // Keep Cupertino's edge detector even with motion disabled. Replacing
      // the transition with the child alone silently removes swipe-to-go-back.
      final reduced = reducedMotion(context) && !popGestureInProgress;
      return super.buildTransitions(
        context,
        reduced ? kAlwaysCompleteAnimation : animation,
        reduced ? kAlwaysDismissedAnimation : secondaryAnimation,
        child,
      );
    }
    if (reducedMotion(context)) return child;
    final curve = animation.drive(CurveTween(curve: AppCurve.standard));
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        child: child,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 24 * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }
}

String subjectHeroTag(int subjectId) => 'subject-tile:$subjectId';
