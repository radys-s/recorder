import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/recording_controller.dart';
import '../../../core/accent.dart';
import '../../../core/formatting.dart';
import '../../../core/logging.dart';
import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/level_waveform.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/daos/subjects_dao.dart';
import '../../meeting_detail/meeting_detail_providers.dart';
import '../../meeting_detail/widgets/recording_indicator_banner.dart';
import '../../subjects/subjects_providers.dart';
import '../../subjects/timetable.dart';

/// The top of the dashboard: a dark stage in both themes with one gold record
/// control, which becomes the recording itself while a lesson runs — clock,
/// live level, the last heard line and the three things worth doing then.
///
/// The list below it is drawn as a sheet overlapping the stage; the stage
/// paints that sheet's rounded top edge itself, so the list can stay a plain
/// sliver list.
class DashboardStage extends ConsumerStatefulWidget {
  const DashboardStage({
    super.key,
    required this.date,
    required this.liveSubjectName,
    required this.onStart,
    required this.onOpen,
    required this.onResume,
    required this.onSearch,
    required this.onSettings,
  });

  /// Eyebrow over the title, e.g. `sobota 26. září`.
  final String date;

  /// Subject of the lesson being recorded, when it has one.
  final String? liveSubjectName;
  final VoidCallback onStart;
  final VoidCallback onOpen;
  final VoidCallback onResume;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  /// How far the list's sheet reaches up into the stage.
  static const sheetOverlap = 28.0;

  @override
  ConsumerState<DashboardStage> createState() => _DashboardStageState();
}

class _DashboardStageState extends ConsumerState<DashboardStage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// One ring that leaves the record disc when a lesson starts or resumes.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: AppDuration.slow,
  );

  /// Moves the clock while recording. RecordingState only changes when a
  /// chunk closes, so the second hand needs its own tick.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _burst.dispose();
    super.dispose();
  }

  /// The timetable hint depends on the clock; coming back to the app is when
  /// it most needs to be fresh. No periodic timer while idle.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _syncTicker(bool recording) {
    if (recording && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!recording && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _playBurst() {
    if (reducedMotion(context)) return;
    _burst.forward(from: 0);
  }

  void _start() {
    _playBurst();
    widget.onStart();
  }

  void _resume() {
    HapticFeedback.mediumImpact();
    _playBurst();
    widget.onResume();
  }

  Future<void> _markImportant() async {
    final state = ref.read(recordingControllerProvider);
    final meetingId = state.meetingId;
    final startedAt = state.startedAt;
    if (meetingId == null || startedAt == null) return;
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref.read(chatMessagesDaoProvider).addImportant(
        meetingId: meetingId,
        atMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
    } catch (e, st) {
      AppLog.e('dashboard.stage', 'could not mark important', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Důležité se nepodařilo uložit.')),
        );
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Označeno jako důležité'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  /// `Teď Čeština · do 9:45` / `Další Dějepis v 10:00`, or null.
  String? _hint(List<TimetableSlot> slots, List<SubjectSummary> subjects) {
    final hint = todaySlotHint(slots, DateTime.now());
    if (hint == null) return null;
    String? name;
    for (final s in subjects) {
      if (s.subject.id == hint.slot.subjectId) name = s.subject.name;
    }
    if (name == null) return null;
    return hint.running
        ? 'Teď $name · do ${formatMinuteOfDay(hint.slot.endMinute)}'
        : 'Další $name v ${formatMinuteOfDay(hint.slot.startMinute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final recording = ref.watch(
      recordingControllerProvider.select((s) => s.isRecording),
    );
    final paused = ref.watch(
      recordingControllerProvider.select((s) => s.isPaused),
    );
    // IndexedStack keeps this widget mounted on hidden tabs; a Dart Timer is
    // not suspended by TickerMode, so only tick while the stage is foreground.
    _syncTicker(
      recording &&
          ref.watch(dashboardStageVisibleProvider) &&
          ref.watch(dashboardStageInViewProvider),
    );
    final live = recording && !paused;
    final reduced = reducedMotion(context);

    final glow = live
        ? AftermindPalette.recordDark.withValues(alpha: 0.16)
        : context.accent.fill.withValues(alpha: paused ? 0.08 : 0.20);

    final Widget body = recording
        ? _LiveStage(
            key: const ValueKey('live'),
            paused: paused,
            subjectName: widget.liveSubjectName,
            onImportant: _markImportant,
            onStop: () => confirmAndStopRecording(context, ref),
            onPause: () {
              HapticFeedback.mediumImpact();
              ref.read(recordingControllerProvider.notifier).pause();
            },
            onResume: _resume,
            onOpen: widget.onOpen,
          )
        : _IdleStage(
            key: const ValueKey('idle'),
            burst: _burst,
            hint: _hint(
              ref.watch(allSlotsProvider).valueOrNull ?? const [],
              ref.watch(subjectsProvider).valueOrNull ?? const [],
            ),
            onStart: _start,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: dark ? AftermindPalette.stageDark : AftermindPalette.stage,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: reduced ? Duration.zero : AppDuration.slow,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 0.05),
                    radius: 0.85,
                    colors: [glow, glow.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Header(
                    date: widget.date,
                    onSearch: widget.onSearch,
                    onSettings: widget.onSettings,
                  ),
                  AnimatedSize(
                    duration: reduced ? Duration.zero : AppDuration.base,
                    curve: AppCurve.standard,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: reduced ? Duration.zero : AppDuration.base,
                      switchInCurve: AppCurve.standard,
                      switchOutCurve: AppCurve.exit,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween(
                            begin: 0.97,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      child: body,
                    ),
                  ),
                  const SizedBox(height: Gap.xl + DashboardStage.sheetOverlap),
                ],
              ),
            ),
            // The rounded top of the sheet the list sits on.
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              height: DashboardStage.sheetOverlap + 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(DashboardStage.sheetOverlap),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.onSearch,
    required this.onSettings,
  });

  final String date;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.md, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: const Text(
                    'Dnes',
                    style: TextStyle(
                      color: AftermindPalette.stageInk,
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _GlassIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Hledat',
            onTap: onSearch,
          ),
          const SizedBox(width: Gap.sm),
          _GlassIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Nastavení',
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

/// A round translucent control on the stage.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
    this.color = AftermindPalette.stageInk,
    this.iconSize = 21,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.white.withValues(alpha: 0.10),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: iconSize, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Idle ────────────────────────────────────────────────────────────────────

class _IdleStage extends StatelessWidget {
  const _IdleStage({
    super.key,
    required this.burst,
    required this.hint,
    required this.onStart,
  });

  final Animation<double> burst;
  final String? hint;
  final VoidCallback onStart;

  static const _ring = 240.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: Gap.lg),
        Semantics(
          button: true,
          label: 'Nahrát hodinu',
          hint: 'Otevře nastavení nové nahrávky.',
          onTap: onStart,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onStart,
            behavior: HitTestBehavior.opaque,
            child: SizedBox.square(
              dimension: _ring,
              child: AnimatedBuilder(
                animation: burst,
                builder: (context, child) {
                  final t = burst.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          size: Size.square(_ring),
                          painter: RingBarsPainter(
                            accent: context.accent.palette,
                          ),
                        ),
                      ),
                      if (t > 0 && t < 1)
                        Container(
                          width: 100 + 110 * Curves.easeOut.transform(t),
                          height: 100 + 110 * Curves.easeOut.transform(t),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.accent.highlight.withValues(
                                alpha: 0.7 * (1 - t),
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                      child!,
                    ],
                  );
                },
                child: const _RecordDisc(),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        const Text(
          'Nahrát hodinu',
          style: TextStyle(
            color: AftermindPalette.stageInk,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: Gap.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          child: Text(
            hint ?? 'Přepis začne přibývat během pár vteřin',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              height: 1.3,
              fontFeatures: kTabularFigures,
            ),
          ),
        ),
      ],
    );
  }
}

/// The accent disc inside a ring that sweeps through the accent's hues.
class _RecordDisc extends StatelessWidget {
  const _RecordDisc();

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return SizedBox(
      width: 104,
      height: 104,
      child: GradientOutline(
        gradient: accent.ring,
        circle: true,
        width: 3,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: accent.fillGradient,
              boxShadow: [
                BoxShadow(
                  color: accent.fill.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: accent.partner.withValues(alpha: 0.25),
                  blurRadius: 44,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(Icons.mic_rounded, size: 36, color: accent.onFill),
          ),
        ),
      ),
    );
  }
}

/// 72 short radial bars around the record disc — a still waveform, the
/// stage's quiet ornament. Painted once; nothing here animates.
class RingBarsPainter extends CustomPainter {
  const RingBarsPainter({this.accent});

  /// When set, the bars pick up the accent's hues around the ring instead of
  /// plain white.
  final AccentPalette? accent;

  static const bars = 72;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final inner = size.width / 2 - 52;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    for (var i = 0; i < bars; i++) {
      final a = i / bars * 2 * math.pi - math.pi / 2;
      // A gentle, fixed texture: longer bars drift around the ring.
      final wave = (math.sin(i * 0.45) + math.sin(i * 0.17 + 1.3)) / 2;
      final length = 8 + 10 * (wave * wave);
      final alpha = 0.16 + 0.10 * wave.abs();
      final tint = accent;
      if (tint == null) {
        paint.color = Colors.white.withValues(alpha: alpha);
      } else {
        // Around the ring: highlight → partner → highlight, faded into white
        // so it stays an ornament rather than a second colour block.
        final t = (math.sin(i / bars * 2 * math.pi) + 1) / 2;
        final hue = Color.lerp(tint.highlight, tint.partner, t)!;
        paint.color = Color.lerp(
          Colors.white,
          hue,
          0.55,
        )!.withValues(alpha: alpha + 0.08);
      }
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * inner,
        center + dir * (inner + length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RingBarsPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

// ── Recording ───────────────────────────────────────────────────────────────

class _LiveStage extends ConsumerWidget {
  const _LiveStage({
    super.key,
    required this.paused,
    required this.subjectName,
    required this.onImportant,
    required this.onStop,
    required this.onPause,
    required this.onResume,
    required this.onOpen,
  });

  final bool paused;
  final String? subjectName;
  final VoidCallback onImportant;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider);
    final meetingId = state.meetingId;
    final elapsed = state.elapsed;
    final width = MediaQuery.sizeOf(context).width;
    final line = meetingId == null ? null : _lastLine(ref, meetingId);
    const red = AftermindPalette.recordDark;
    final muted = Colors.white.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
      child: Column(
        children: [
          const SizedBox(height: Gap.lg),
          _StatePill(paused: paused, subjectName: subjectName),
          const SizedBox(height: Gap.sm),
          Semantics(
            label: 'Nahráno ${formatClock(elapsed)}',
            excludeSemantics: true,
            child: Text(
              formatClock(elapsed),
              style: const TextStyle(
                color: AftermindPalette.stageInk,
                fontSize: 60,
                height: 1.1,
                fontWeight: FontWeight.w500,
                letterSpacing: -1.5,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          SizedBox(
            height: 48,
            child: paused
                ? Center(
                    child: Container(
                      height: 2,
                      width: math.min(width - 64, 320),
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  )
                : LevelWaveform(
                    level: ref.read(recordingControllerProvider.notifier).level,
                    color: red,
                    bars: 44,
                    width: math.min(width - 64, 320),
                    height: 48,
                  ),
          ),
          const SizedBox(height: Gap.md),
          SizedBox(
            height: 42,
            child: Text(
              line == null
                  ? (paused ? 'Pozastaveno' : 'Poslouchám…')
                  : '„$line"',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
          if (state.weakSignal) ...[
            const SizedBox(height: Gap.xs),
            Text(
              'Slabý signál — polož telefon blíž k vyučujícímu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.accent.palette.darkText.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: Gap.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (paused)
                _RoundAction(
                  icon: Icons.stop_rounded,
                  label: 'Ukončit',
                  onTap: onStop,
                )
              else
                _RoundAction(
                  icon: Icons.star_rounded,
                  iconColor: context.accent.palette.darkText,
                  label: 'Důležité',
                  onTap: onImportant,
                ),
              if (paused)
                _BigControl(
                  label: 'Pokračovat',
                  onTap: onResume,
                  child: const _PlayDisc(),
                )
              else
                _BigControl(
                  label: 'Ukončit',
                  onTap: onStop,
                  child: const _StopSquare(),
                ),
              _RoundAction(
                icon: Icons.notes_rounded,
                label: 'Přepis',
                onTap: onOpen,
              ),
            ],
          ),
          if (!paused)
            TextButton.icon(
              onPressed: onPause,
              style: TextButton.styleFrom(foregroundColor: muted),
              icon: const Icon(Icons.pause_rounded, size: 18),
              label: const Text('Pozastavit'),
            )
          else
            const SizedBox(height: 48),
        ],
      ),
    );
  }

  /// The newest non-empty transcript text, trimmed to its last sentence-ish
  /// tail so two lines show what was just said rather than what came first.
  String? _lastLine(WidgetRef ref, int meetingId) {
    final segments =
        ref.watch(meetingSegmentsProvider(meetingId)).valueOrNull ?? const [];
    for (final s in segments.reversed) {
      final text = s.content?.trim();
      if (text != null && text.isNotEmpty) {
        return text.length > 140
            ? '…${text.substring(text.length - 140)}'
            : text;
      }
    }
    return null;
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.paused, required this.subjectName});

  final bool paused;
  final String? subjectName;

  @override
  Widget build(BuildContext context) {
    final color = paused
        ? Colors.white.withValues(alpha: 0.7)
        : AftermindPalette.recordDark;
    final label = [
      paused ? 'Pozastaveno' : 'Nahrává se',
      ?subjectName,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paused ? Icons.pause_rounded : Icons.fiber_manual_record,
            size: paused ? 14 : 9,
            color: color,
          ),
          const SizedBox(width: Gap.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: paused ? color : const Color(0xFFFFC2BC),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = AftermindPalette.stageInk,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _GlassIconButton(
            icon: icon,
            tooltip: label,
            onTap: onTap,
            size: 56,
            iconSize: 26,
            color: iconColor,
          ),
          const SizedBox(height: Gap.sm),
          _ActionLabel(label),
        ],
      ),
    );
  }
}

/// The central control: a gold ring around a red stop, or a gold play.
class _BigControl extends StatelessWidget {
  const _BigControl({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: label == 'Ukončit'
              ? 'Ukončit nahrávání'
              : 'Pokračovat v nahrávání',
          onTap: onTap,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: GradientOutline(
              gradient: context.accent.ring,
              circle: true,
              width: 3,
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(7),
                child: child,
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _ActionLabel(label),
      ],
    );
  }
}

class _StopSquare extends StatelessWidget {
  const _StopSquare();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AftermindPalette.recordDark,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AftermindPalette.recordDark.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayDisc extends StatelessWidget {
  const _PlayDisc();

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: accent.fillGradient,
      ),
      child: Icon(Icons.play_arrow_rounded, size: 34, color: accent.onFill),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
