import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/recording_controller.dart';
import '../../../core/formatting.dart';
import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/level_waveform.dart';
import '../meeting_detail_screen.dart';

/// Asks before ending a recording, since it cannot be resumed afterwards.
/// Shared by this strip and the dashboard stage.
Future<void> confirmAndStopRecording(
  BuildContext context,
  WidgetRef ref,
) async {
  final stop = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.stop_circle_outlined),
      title: const Text('Ukončit nahrávání?'),
      content: const Text(
        'Dosavadní zvuk se uloží a přepis doběhne. Nahrávání už nepůjde obnovit.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Pokračovat v hodině'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.stop),
          label: const Text('Ukončit'),
        ),
      ],
    ),
  );
  if (stop != true || !context.mounted) return;
  HapticFeedback.mediumImpact();
  await ref.read(recordingControllerProvider.notifier).stop();
}

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
    final isRecording =
        ref.watch(recordingControllerProvider.select((s) => s.isRecording)) &&
        !(ref.watch(dashboardStageVisibleProvider) &&
            ref.watch(dashboardStageInViewProvider));

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
          // Navigator's active route uses BlockSemantics. Painting it after
          // the strip hid the strip from screen readers even while visible.
          // Reverse paint order, then lay out upwards to keep the strip above.
          verticalDirection: VerticalDirection.up,
          children: [
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
            // Animate layout instead of overlaying the strip across content.
            SizeTransition(
              sizeFactor: _curve,
              alignment: Alignment.topCenter,
              child: const _Banner(),
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

  /// The lesson whose weak-signal warning has been read and waved away. Kept
  /// per meeting, so the next lesson is warned again.
  /// `<lesson>:<kind>` of the notice the student closed, so a different
  /// problem in the same lesson is still shown.
  String? _noticeDismissed;

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

    // `popUntil` evaluates each route from the top down. Returning true for
    // every route only inspected the top one, so the old code pushed a second
    // detail screen whenever Settings covered the original meeting.
    var found = false;
    navigator.popUntil((route) {
      if (route.settings.name == name) {
        found = true;
        return true;
      }
      return route.isFirst;
    });

    if (!found) {
      navigator.push(MeetingDetailScreen.route(meetingId));
    }
  }

  // The strip lives above the Navigator, so its own context cannot open a
  // dialog; the navigator's context can.
  Future<void> _confirmStop(BuildContext context) =>
      confirmAndStopRecording(appNavigatorKey.currentContext ?? context, ref);

  void _togglePause() {
    HapticFeedback.mediumImpact();
    final controller = ref.read(recordingControllerProvider.notifier);
    if (ref.read(recordingControllerProvider).isPaused) {
      controller.resume();
    } else {
      controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The clock has its own ticker, but pause state has to reach this strip
    // immediately: it changes both the copy and the actions a user can take.
    final recording = ref.watch(recordingControllerProvider);
    final meetingId = recording.meetingId;
    final paused = recording.isPaused;
    final elapsed = recording.elapsed;
    // One notice at a time, the most serious first.
    final (noticeKind, noticeText) = recording.micSilent
        ? ('silent', 'Mikrofon nic neslyší — zkontroluj, jestli není zakrytý nebo ztlumený')
        : recording.lowDisk
        ? ('disk', 'V telefonu dochází místo — uvolni ho, ať se hodina uloží celá')
        : recording.weakSignal
        ? ('weak', 'Slabý signál — polož telefon blíž k vyučujícímu')
        : ('', '');
    final noticeKey = '$meetingId:$noticeKind';
    final scheme = Theme.of(context).colorScheme;
    final warn = noticeKind.isNotEmpty && _noticeDismissed != noticeKey;
    final background = paused
        ? scheme.secondaryContainer
        : scheme.errorContainer;
    final foreground = paused
        ? scheme.onSecondaryContainer
        : scheme.onErrorContainer;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    Widget status() => Row(
      children: [
        paused
            ? Icon(Icons.pause_circle_filled, color: foreground)
            : const _PulsingDot(),
        const SizedBox(width: Gap.sm),
        // The clock never gives way; the word before it may.
        Flexible(
          child: Text(
            paused ? 'Pozastaveno' : 'Nahrává se',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          ' · ${formatClock(elapsed)}',
          maxLines: 1,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w600,
            fontFeatures: kTabularFigures,
          ),
        ),
        if (!paused && !largeText) ...[
          const SizedBox(width: Gap.sm),
          LevelWaveform(
            level: ref.read(recordingControllerProvider.notifier).level,
            color: foreground,
          ),
        ],
      ],
    );

    Widget actions() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: paused ? 'Pokračovat v nahrávání' : 'Pozastavit nahrávání',
          onTap: _togglePause,
          excludeSemantics: true,
          child: IconButton(
            onPressed: _togglePause,
            icon: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: foreground,
            ),
          ),
        ),
        // This banner is built above Navigator, so an IconButton tooltip has
        // no Overlay ancestor and throws as soon as the strip opens.
        Semantics(
          button: true,
          label: 'Ukončit nahrávání',
          onTap: () => _confirmStop(context),
          excludeSemantics: true,
          child: IconButton(
            onPressed: () => _confirmStop(context),
            icon: Icon(Icons.stop, size: 20, color: foreground),
            style: IconButton.styleFrom(foregroundColor: foreground),
          ),
        ),
      ],
    );

    return Material(
      color: background,
      child: InkWell(
        onTap: meetingId == null ? null : () => _openMeeting(meetingId),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.sm, Gap.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (largeText || constraints.maxWidth < 360) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          status(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: actions(),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: status()),
                        actions(),
                      ],
                    );
                  },
                ),
                if (warn)
                  _RecordingNotice(
                    message: noticeText,
                    onDismiss: () => setState(() => _noticeDismissed = noticeKey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A weak signal is said once per lesson, and only after a full minute of it:
/// the microphone is hearing the room more than the teacher, and no amount of
/// processing afterwards can put back what never reached it. Moving the phone
/// can. A silent microphone and a filling disk use the same strip.
class _RecordingNotice extends StatelessWidget {
  const _RecordingNotice({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Row(
        children: [
          Icon(
            Icons.mic_off_outlined,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
          Semantics(
            button: true,
            label: 'Skrýt upozornění',
            onTap: onDismiss,
            excludeSemantics: true,
            child: IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: scheme.onErrorContainer),
            ),
          ),
        ],
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
