import 'dart:async';

import 'package:flutter/material.dart';

import '../motion.dart';

/// Fades and lifts [child] into place, exactly once.
///
/// Used for rows arriving in a list. The "exactly once" is the whole point:
/// a list whose rows replay their entrance every time you scroll past them is
/// the single most common way motion turns from helpful into irritating. The
/// caller decides — it keeps a set of ids it has already shown and passes
/// [enabled] accordingly — because a `ListView` recycles its elements, so this
/// widget cannot tell a genuinely new row from one that just scrolled back
/// into view.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.enabled = true,
    this.delay = Duration.zero,
    this.offset = 8,
  });

  final Widget child;

  /// False renders [child] in its final state immediately, no animation.
  final bool enabled;

  /// For staggering a group. Kept short — see [AppMotion.stagger].
  final Duration delay;

  /// How far below its resting place the child starts, in logical pixels.
  final double offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  /// Latched at mount. The caller computes [Entrance.enabled] from a set of
  /// already-seen ids, so it flips to false on the very next rebuild — which
  /// for a live transcript happens well inside these 450 ms. Reading the
  /// widget's field in `build` would therefore cut the animation off partway.
  late final bool _run = widget.enabled;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDuration.base,
    value: _run ? 0 : 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: AppCurve.standard,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (!_run) return;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _delay?.cancel();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The final state, not a frozen first frame: someone who asked for less
    // motion must still see the row.
    if (!_run || reducedMotion(context)) return widget.child;

    return AnimatedBuilder(
      animation: _curve,
      // Passed as `child` so the subtree is built once and only the transform
      // and opacity are recomputed per frame.
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}
