import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Maps a frame's RMS (0–1 of full scale) to a bar height 0–1.
///
/// On a decibel scale from -60 dBFS (nothing) to -10 dBFS (full bar): linear
/// RMS would leave a distant teacher as a flat line and a cough as the only
/// thing ever visible.
double levelToBar(double rms) {
  if (rms.isNaN || rms <= 0) return 0;
  final db = 20 * math.log(rms) / math.ln10;
  return ((db + 60) / 50).clamp(0.0, 1.0);
}

/// The last few seconds of microphone level as bars, newest on the right.
///
/// Reads the controller's level notifier directly, so only this widget
/// rebuilds on each update — not the banner or the screen around it.
class LevelWaveform extends StatefulWidget {
  const LevelWaveform({
    super.key,
    required this.level,
    required this.color,
    this.bars = 18,
    this.width = 64,
    this.height = 22,
  });

  final ValueListenable<({double rms, double peak})> level;
  final Color color;
  final int bars;
  final double width;
  final double height;

  @override
  State<LevelWaveform> createState() => _LevelWaveformState();
}

class _LevelWaveformState extends State<LevelWaveform> {
  final _history = <double>[];

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_onLevel);
  }

  @override
  void didUpdateWidget(LevelWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      oldWidget.level.removeListener(_onLevel);
      widget.level.addListener(_onLevel);
    }
  }

  @override
  void dispose() {
    widget.level.removeListener(_onLevel);
    super.dispose();
  }

  void _onLevel() {
    setState(() {
      _history.add(levelToBar(widget.level.value.rms));
      if (_history.length > widget.bars) _history.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hlasitost mikrofonu',
      child: CustomPaint(
        size: Size(widget.width, widget.height),
        painter: WaveformPainter(
          values: List.unmodifiable(_history),
          bars: widget.bars,
          color: widget.color,
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.values,
    required this.bars,
    required this.color,
  });

  /// Bar heights 0–1, oldest first. Fewer than [bars] is fine: the missing
  /// ones on the left are drawn as silence.
  final List<double> values;
  final int bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars <= 0 || size.isEmpty) return;
    final slot = size.width / bars;
    final barWidth = math.max(1.0, slot * 0.6);
    final minHeight = math.min(size.height, 3.0);
    final paint = Paint()..color = color;
    final offset = bars - values.length;

    for (var i = 0; i < bars; i++) {
      final index = i - offset;
      final value = index >= 0 && index < values.length ? values[index] : 0.0;
      final h = math.max(minHeight, value.clamp(0.0, 1.0) * size.height);
      final left = i * slot + (slot - barWidth) / 2;
      final top = (size.height - h) / 2;
      // Older bars fade, so the eye reads the right edge as "now".
      paint.color = color.withValues(alpha: 0.35 + 0.65 * (i + 1) / bars);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, h),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.color != color || old.bars != bars || !listEquals(old.values, values);
}
