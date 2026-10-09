import 'package:flutter/material.dart';

import '../motion.dart';

/// Grey lines standing in for text that is still being written.
///
/// A soft accent sheen sweeps across them. Under reduced motion they stay
/// still. Purely decorative, so it is hidden from screen readers; the caller
/// puts the real status text next to it.
class TextSkeleton extends StatefulWidget {
  const TextSkeleton({super.key, this.lines = 5});

  final int lines;

  @override
  State<TextSkeleton> createState() => _TextSkeletonState();
}

class _TextSkeletonState extends State<TextSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _controller?.dispose();
      _controller = null;
    } else {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Line widths as a share of the available width, so the block reads as a
  // paragraph rather than a ruler.
  static const _widths = [1.0, 0.92, 1.0, 0.78, 0.55];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final glow = scheme.primary;
    final controller = _controller;

    Widget lines(double sweep) => LayoutBuilder(
      builder: (_, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.lines; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 12,
                width: box.maxWidth * _widths[i % _widths.length],
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment(-1 + sweep * 3, 0),
                    end: Alignment(sweep * 3, 0),
                    colors: [base, Color.lerp(base, glow, .22)!, base],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return ExcludeSemantics(
      child: controller == null
          ? lines(-.4)
          : AnimatedBuilder(
              animation: controller,
              builder: (_, _) => lines(controller.value),
            ),
    );
  }
}
