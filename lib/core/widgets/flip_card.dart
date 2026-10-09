import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';

/// Turns between two faces around the vertical axis, like a flash card.
///
/// Only the face that is turned towards the viewer is built, so a screen
/// reader and `find` see one face at a time. Under reduced motion the faces
/// swap with no turn at all.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.flipped,
  });

  final Widget front;
  final Widget back;

  /// False shows [front], true shows [back].
  final bool flipped;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDuration.base,
    value: widget.flipped ? 1 : 0,
  );
  late final Animation<double> _curve = _controller.drive(
    CurveTween(curve: AppCurve.standard),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) _controller.value = widget.flipped ? 1 : 0;
  }

  @override
  void didUpdateWidget(FlipCard old) {
    super.didUpdateWidget(old);
    if (old.flipped == widget.flipped) return;
    if (reducedMotion(context)) {
      _controller.value = widget.flipped ? 1 : 0;
    } else {
      _controller.animateTo(widget.flipped ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) {
      return widget.flipped ? widget.back : widget.front;
    }
    return AnimatedBuilder(
      animation: _curve,
      builder: (_, _) {
        final t = _curve.value;
        final showBack = t >= 0.5;
        final angle = t * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(showBack ? angle - math.pi : angle),
          child: showBack ? widget.back : widget.front,
        );
      },
    );
  }
}
