import 'package:flutter/material.dart';

import '../motion.dart';

/// Sinks its child slightly while a finger is on it.
///
/// Purely visual: it listens to raw pointers instead of taking part in the
/// gesture arena, so the [InkWell] inside a card still gets the tap, the long
/// press and the ripple. Under reduced motion the child never scales.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});

  final Widget child;

  /// How far the child shrinks while pressed.
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = reducedMotion(context);

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !reduced ? widget.scale : 1,
        duration: reduced ? Duration.zero : AppDuration.instant,
        curve: AppCurve.standard,
        child: widget.child,
      ),
    );
  }
}
