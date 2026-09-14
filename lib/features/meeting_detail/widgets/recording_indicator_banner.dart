import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/recording_controller.dart';
import '../../../core/formatting.dart';
import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/theme.dart';
import '../meeting_detail_screen.dart';

/// The "recording in progress" strip, mounted from `MaterialApp.builder` so it
/// sits above the Navigator and therefore above *every* route — a recording is
/// easy to forget about, and forgetting is the one failure this app must not
/// allow.
///
/// Wraps the app's [child] and returns it untouched when nothing is being
/// recorded, so in the common case it costs one provider subscription and no
/// extra layout.
class RecordingIndicatorBanner extends ConsumerStatefulWidget {
  const RecordingIndicatorBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RecordingIndicatorBanner> createState() =>
      _RecordingIndicatorBannerState();
}

class _RecordingIndicatorBannerState
    extends ConsumerState<RecordingIndicatorBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: AppDuration.slow,
    reverseDuration: AppDuration.quick,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _open,
    curve: AppCurve.standard,
    reverseCurve: AppCurve.exit,
  );

  @override
  void dispose() {
    _curve.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(
      recordingControllerProvider.select((s) => s.isRecording),
    );

    // Reduced motion gets the end state on the spot; everyone else gets the
    // strip sliding the routes down instead of teleporting them.
    if (reducedMotion(context)) {
      _open.value = isRecording ? 1 : 0;
    } else if (isRecording) {
      _open.forward();
    } else {
      _open.reverse();
    }

    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        // Fully closed is the common case: the app then renders exactly as it
        // would without this widget in the tree at all.
        if (_curve.value == 0) return child!;

        final media = MediaQuery.of(context);
        return Column(
          children: [
            // Animating a height, against the usual rule. It is one element,
            // and the alternative — overlaying the strip — would cover the top
            // of whatever screen the user is on.
            SizeTransition(
              sizeFactor: _curve,
              alignment: Alignment.topCenter,
              child: const _Banner(),
            ),
            // The banner consumes the status bar inset itself (the SafeArea in
            // _Banner), so the routes below must not consume it again or every
            // Scaffold grows a second, empty status-bar-sized gap above its
            // AppBar. Interpolated rather than switched: dropping the inset the
            // moment the banner starts opening would jerk the whole app up by a
            // status bar and then let the banner push it back down.
            Expanded(
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(
                    top: media.padding.top * (1 - _curve.value),
                  ),
                ),
                child: child!,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Banner extends ConsumerStatefulWidget {
  const _Banner();

  @override
  ConsumerState<_Banner> createState() => _BannerState();
}

class _BannerState extends ConsumerState<_Banner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();

    // RecordingState changes only when a chunk closes — once every 20-30 s —
    // but the clock has to move every second, so it gets its own tick. This
    // state only exists while recording, so the timer stops with the banner.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Brings the active meeting to the front: back to it when it is already on
  /// the stack (the usual case — the user wandered off to Settings), a fresh
  /// push otherwise. Pushing unconditionally would stack a second copy of the
  /// same screen on top of the first.
  void _openMeeting(int meetingId) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final name = MeetingDetailScreen.routeNameFor(meetingId);

    // A predicate that is always true pops nothing; visiting the stack this way
    // is the only reading of it the public Navigator API offers.
    var alreadyOpen = false;
    navigator.popUntil((route) {
      if (route.settings.name == name) alreadyOpen = true;
      return true;
    });

    if (alreadyOpen) {
      navigator.popUntil((route) => route.settings.name == name);
    } else {
      navigator.push(MeetingDetailScreen.route(meetingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the two fields this strip shows; the clock has its own ticker.
    final meetingId =
        ref.watch(recordingControllerProvider.select((s) => s.meetingId));
    final startedAt =
        ref.watch(recordingControllerProvider.select((s) => s.startedAt));
    final elapsed = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.errorContainer,
      child: InkWell(
        onTap: meetingId == null ? null : () => _openMeeting(meetingId),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.sm, Gap.xs),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Nahrává se · ${formatClock(elapsed)}',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                      // The clock ticks every second; without tabular digits
                      // the whole line shifts as they change width.
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(recordingControllerProvider.notifier).stop(),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Zastavit'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A solid dot with a halo expanding out of it, like a radar ping.
///
/// The previous version faded the whole dot down to 20% opacity, which reads as
/// "something is broken" rather than "something is running" — and at the bottom
/// of the fade it was nearly invisible against the container colour in dark
/// mode. The dot itself now stays put and fully opaque; only the halo moves.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  static const _dotSize = 10.0;
  static const _boxSize = _dotSize * 2.8;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = Container(
      width: _dotSize,
      height: _dotSize,
      decoration: BoxDecoration(
        color: scheme.onErrorContainer,
        shape: BoxShape.circle,
      ),
    );

    // A loop in the corner of every screen is exactly what reduced motion is
    // for. The dot stays — it is the indicator, not decoration.
    if (reducedMotion(context)) {
      return SizedBox(
        width: _boxSize,
        height: _boxSize,
        child: Center(child: dot),
      );
    }

    return SizedBox(
      width: _boxSize,
      height: _boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              // Eased, so the ring leaps away from the dot and then drifts,
              // rather than expanding at a constant machine-like rate.
              final t = Curves.easeOutCubic.transform(_pulse.value);
              final size = _dotSize * (1 + t * 1.7);
              return Opacity(
                opacity: (1 - t) * 0.45,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: scheme.onErrorContainer,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          dot,
        ],
      ),
    );
  }
}
