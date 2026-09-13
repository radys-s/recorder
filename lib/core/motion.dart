import 'package:flutter/widgets.dart';

/// One source of truth for how things move.
///
/// Ad-hoc durations scattered across widgets are why interfaces feel
/// inconsistent — two elements animating the same event at 200 ms and 400 ms
/// read as a glitch rather than as one motion.
abstract final class AppDuration {
  const AppDuration._();

  /// Press feedback: the user already knows what they did, this only confirms.
  static const instant = Duration(milliseconds: 120);

  /// Hover, selection, an element leaving.
  static const quick = Duration(milliseconds: 280);

  /// The default. An element entering, a placeholder becoming real text.
  static const base = Duration(milliseconds: 450);

  /// Larger blocks: a banner opening, a panel arriving.
  static const slow = Duration(milliseconds: 700);
}

abstract final class AppCurve {
  const AppCurve._();

  /// Fast to start, calm to land. Used for everything that enters or resizes.
  static const standard = Cubic(0.22, 1, 0.36, 1);

  /// For things leaving, where the ease-out tail would just look slow.
  static const exit = Curves.easeInCubic;
}

abstract final class AppMotion {
  const AppMotion._();

  /// Delay between siblings in a staggered group, so a list reads as a
  /// sequence rather than a flash.
  static const stagger = Duration(milliseconds: 60);

  /// Cap on how far a stagger runs. Without it a 200-row list would still be
  /// animating a minute after it appeared.
  static const staggerMaxIndex = 8;

  static Duration staggerDelay(int index) =>
      stagger * (index > staggerMaxIndex ? staggerMaxIndex : index);
}

/// True when the platform asks for reduced motion (iOS Reduce Motion, Android
/// Remove animations).
///
/// Every animation in the app branches on this and renders its **final** state
/// directly. The classic failure is disabling the animation but leaving the
/// element at `opacity: 0` — content that is invisible for someone who asked
/// for less movement is worse than the movement was.
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
