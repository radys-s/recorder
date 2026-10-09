import 'package:flutter/material.dart';

import '../motion.dart';

/// Fades and lifts a group of children in one after another.
///
/// One controller drives every child through its own slice of the timeline, so
/// there is no per-child timer to leave pending. At most [maxStaggered]
/// children are delayed; the rest share the last slot, so a long document
/// never takes seconds to appear. With [animate] false, or under reduced
/// motion, every child is in its final state from the first frame.
class StaggerReveal extends StatefulWidget {
  const StaggerReveal({
    super.key,
    required this.children,
    this.animate = true,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.maxStaggered = 8,
  }) : assert(maxStaggered > 0);

  final List<Widget> children;
  final bool animate;
  final CrossAxisAlignment crossAxisAlignment;
  final int maxStaggered;

  @override
  State<StaggerReveal> createState() => _StaggerRevealState();
}

class _StaggerRevealState extends State<StaggerReveal>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(vsync: this, duration: AppDuration.slow)
        ..forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) _controller?.value = 1;
  }

  @override
  void didUpdateWidget(StaggerReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reveal is a mount-time decision, never replayed by a stream rebuild.
    if (!widget.animate) _controller?.value = 1;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || reducedMotion(context)) {
      return Column(
        crossAxisAlignment: widget.crossAxisAlignment,
        children: widget.children,
      );
    }
    final count = widget.children.length;
    final steps = count < 2 ? 1 : (count - 1).clamp(1, widget.maxStaggered);
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        for (var i = 0; i < count; i++)
          _slot(controller, widget.children[i], i.clamp(0, steps), steps),
      ],
    );
  }

  Widget _slot(AnimationController c, Widget child, int index, int steps) {
    // Each child owns a window of 55% of the timeline, shifted by its index.
    final start = steps == 0 ? 0.0 : 0.45 * index / steps;
    // CurveTween owns no status listener; unlike CurvedAnimation it needs no
    // disposal when a document rebuilds or changes the number of blocks.
    final animation = c.drive(
      CurveTween(
        curve: Interval(start, start + 0.55, curve: AppCurve.standard),
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
