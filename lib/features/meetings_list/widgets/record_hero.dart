import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/spacing.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/daos/subjects_dao.dart';
import '../../subjects/subjects_providers.dart';
import '../../subjects/timetable.dart';

/// The home screen's first and largest element: start a lesson, or get back to
/// the one running.
///
/// A graphite panel in both themes, so the one gold button on it is the
/// brightest thing on the screen. Motion lives only here and only when it
/// means something: a burst when a recording starts or resumes, and slow smoke
/// while it runs. Idle, nothing animates and nothing repaints.
class RecordHero extends ConsumerStatefulWidget {
  const RecordHero({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.onStart,
    required this.onOpen,
    required this.onResume,
  });

  final bool isRecording;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onOpen;
  final VoidCallback onResume;

  @override
  ConsumerState<RecordHero> createState() => _RecordHeroState();
}

class _RecordHeroState extends ConsumerState<RecordHero>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  /// Slow drift of the smoke while recording. Stopped otherwise.
  late final AnimationController _smoke = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  /// One-shot ring that leaves the button when a recording starts or resumes.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: AppDuration.slow,
  );

  bool get _live => widget.isRecording && !widget.isPaused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSmoke();
  }

  @override
  void didUpdateWidget(covariant RecordHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasLive = oldWidget.isRecording && !oldWidget.isPaused;
    if (wasLive != _live) {
      _syncSmoke();
      if (_live) _playBurst();
    }
  }

  void _syncSmoke() {
    if (_live && !reducedMotion(context)) {
      if (!_smoke.isAnimating) _smoke.repeat();
    } else {
      _smoke.stop();
    }
  }

  void _playBurst() {
    if (reducedMotion(context)) return;
    _burst.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _smoke.dispose();
    _burst.dispose();
    super.dispose();
  }

  /// The hint depends on the clock. No periodic timer (it would outlive a
  /// widget test); coming back to the app is when it most needs to be fresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  String? _hint(List<TimetableSlot> slots, List<SubjectSummary> subjects) {
    final hint = todaySlotHint(slots, DateTime.now());
    if (hint == null) return null;
    String? name;
    for (final s in subjects) {
      if (s.subject.id == hint.slot.subjectId) name = s.subject.name;
    }
    if (name == null) return null;
    return hint.running
        ? 'Teď: $name do ${formatMinuteOfDay(hint.slot.endMinute)}'
        : 'Další: $name v ${formatMinuteOfDay(hint.slot.startMinute)}';
  }

  void _tap() {
    if (widget.isPaused) {
      _playBurst();
      widget.onResume();
    } else if (widget.isRecording) {
      widget.onOpen();
    } else {
      _playBurst();
      widget.onStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final recording = widget.isRecording;
    final paused = widget.isPaused;
    final hint = recording
        ? null
        : _hint(
            ref.watch(allSlotsProvider).valueOrNull ?? const [],
            ref.watch(subjectsProvider).valueOrNull ?? const [],
          );

    // The panel is graphite in both themes; its text is the dark theme's ink.
    const ink = AftermindPalette.darkInk;
    const muted = AftermindPalette.darkMuted;
    final glow = _live
        ? AftermindPalette.recordDark
        : paused
        ? muted
        : AftermindPalette.gold;

    final label = paused
        ? 'Pokračovat v nahrávání'
        : recording
        ? 'Otevřít probíhající nahrávání'
        : 'Nahrát hodinu';

    return Pressable(
      scale: 0.985,
      child: Semantics(
        button: true,
        label: label,
        hint: paused
            ? 'Obnoví záznam a otevře jeho přepis.'
            : recording
            ? 'Otevře živý přepis.'
            : 'Otevře nastavení nové nahrávky.',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Gap.sheetRadius),
            boxShadow: [
              if (!dark)
                BoxShadow(
                  color: AftermindPalette.graphite.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Gap.sheetRadius),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF26272C), Color(0xFF141518)],
                ),
                border: Border.all(
                  color: glow.withValues(alpha: dark ? 0.22 : 0.12),
                ),
                borderRadius: BorderRadius.circular(Gap.sheetRadius),
              ),
              child: InkWell(
                onTap: _tap,
                splashColor: glow.withValues(alpha: 0.12),
                highlightColor: glow.withValues(alpha: 0.05),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _smoke,
                          builder: (_, _) => CustomPaint(
                            painter: SmokePainter(
                              color: glow,
                              phase: _smoke.value,
                              strength: _live ? 1 : 0.55,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.xl,
                        Gap.xl,
                        Gap.lg,
                        Gap.xl,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Eyebrow(
                                  label: hint ??
                                      (paused
                                          ? 'Pozastaveno'
                                          : recording
                                          ? 'Právě nahrává'
                                          : 'Připraveno'),
                                  color: _live
                                      ? AftermindPalette.recordDark
                                      : paused
                                      ? muted
                                      : AftermindPalette.darkGold,
                                  live: _live,
                                  clock: hint != null,
                                ),
                                const SizedBox(height: Gap.sm),
                                Text(
                                  paused
                                      ? 'Pokračovat'
                                      : recording
                                      ? 'Nahrává se'
                                      : 'Nahrát hodinu',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(color: ink, height: 1.05),
                                ),
                                const SizedBox(height: Gap.xs),
                                Text(
                                  paused
                                      ? 'Klepni a pokračuj v hodině.'
                                      : recording
                                      ? 'Klepni a vrať se k přepisu.'
                                      : 'Přepis začne přibývat během pár vteřin.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Gap.md),
                          _RecordButton(
                            live: _live,
                            paused: paused,
                            burst: _burst,
                            breath: _smoke,
                            idleColor: dark
                                ? scheme.primary
                                : AftermindPalette.darkGold,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({
    required this.label,
    required this.color,
    required this.live,
    required this.clock,
  });

  final String label;
  final Color color;
  final bool live;
  final bool clock;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (clock)
          Icon(Icons.schedule, size: 14, color: color)
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: Gap.sm),
        Flexible(
          child: Text(
            clock ? label : label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: clock ? 0 : 1.2,
              fontFeatures: kTabularFigures,
            ),
          ),
        ),
      ],
    );
  }
}

/// The round button: gold at rest, red while recording, with a halo that
/// breathes with the smoke and a ring that leaves it once on start.
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.live,
    required this.paused,
    required this.burst,
    required this.breath,
    required this.idleColor,
  });

  static const _size = 64.0;

  final bool live;
  final bool paused;
  final Animation<double> burst;
  final Animation<double> breath;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    final color = live
        ? AftermindPalette.recordDark
        : paused
        ? const Color(0xFF3A3B40)
        : idleColor;
    final iconColor = live
        ? const Color(0xFF3B0907)
        : paused
        ? AftermindPalette.darkInk
        : const Color(0xFF2A1F08);

    return SizedBox.square(
      dimension: _size * 1.5,
      child: AnimatedBuilder(
        animation: Listenable.merge([burst, breath]),
        builder: (context, child) {
          // Breath is a sine of the smoke's phase: one swell per 4.5 s.
          final b = live ? (1 - math.cos(breath.value * 4 * math.pi)) / 2 : 0.0;
          final r = burst.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Halo.
              Container(
                width: _size * (1.18 + 0.14 * b),
                height: _size * (1.18 + 0.14 * b),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16 - 0.07 * b),
                ),
              ),
              // Start burst: a thin ring that grows and fades once.
              if (r > 0 && r < 1)
                Container(
                  width: _size * (1 + 0.5 * Curves.easeOut.transform(r)),
                  height: _size * (1 + 0.5 * Curves.easeOut.transform(r)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.7 * (1 - r)),
                      width: 2,
                    ),
                  ),
                ),
              child!,
            ],
          );
        },
        child: AnimatedContainer(
          duration: AppDuration.quick,
          curve: AppCurve.standard,
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: paused ? 0 : 0.45),
                blurRadius: 22,
                spreadRadius: -2,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppDuration.quick,
            child: Icon(
              live
                  ? Icons.graphic_eq
                  : paused
                  ? Icons.play_arrow_rounded
                  : Icons.mic_rounded,
              key: ValueKey((live, paused)),
              color: iconColor,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft, low-contrast smoke: three blurred radial blooms drifting on slow
/// orbits. A static frame when [phase] does not change, so idle costs one
/// paint.
class SmokePainter extends CustomPainter {
  SmokePainter({
    required this.color,
    required this.phase,
    this.strength = 1,
  });

  final Color color;
  final double phase;
  final double strength;

  static const _blooms = [
    // (x, y, radius as share of width, orbit, speed, alpha)
    (0.92, 0.10, 0.62, 0.05, 1.0, 0.20),
    (0.70, 1.05, 0.55, 0.07, -1.0, 0.13),
    (0.18, 0.95, 0.45, 0.06, 2.0, 0.07),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final a = phase * 2 * math.pi;
    for (final (x, y, r, orbit, speed, alpha) in _blooms) {
      final center = Offset(
        size.width * (x + orbit * math.cos(a * speed)),
        size.height * (y + orbit * 1.4 * math.sin(a * speed)),
      );
      final radius = size.width * r;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha * strength),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(SmokePainter old) =>
      old.phase != phase || old.color != color || old.strength != strength;
}
