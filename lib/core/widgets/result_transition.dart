import 'package:flutter/material.dart';

import '../motion.dart';

/// A short acknowledgment of an accepted query/filter, not a new list tree.
/// No outgoing copy is kept: deleted results cannot remain tappable or in
/// semantics, and the child's controllers/focus/scroll position survive.
class ResultTransition extends StatefulWidget {
  const ResultTransition({
    super.key,
    required this.revision,
    required this.child,
  });

  final Object? revision;
  final Widget child;

  @override
  State<ResultTransition> createState() => _ResultTransitionState();
}

class _ResultTransitionState extends State<ResultTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppDuration.quick,
    value: 1,
  );
  late final _curve = _controller.drive(CurveTween(curve: AppCurve.standard));

  @override
  void didUpdateWidget(ResultTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      if (reducedMotion(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (_, child) => Opacity(
      // Keep accepted content accessible throughout; motion is not a gate.
      opacity: 0.7 + 0.3 * _curve.value,
      child: Transform.translate(
        offset: Offset(0, 6 * (1 - _curve.value)),
        child: child,
      ),
    ),
  );
}
