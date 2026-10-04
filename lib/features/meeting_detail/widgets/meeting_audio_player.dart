import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../audio/local_playback.dart';
import '../../../audio/playback_timeline.dart';
import '../../../audio/playback_files.dart';
import '../../../audio/recording_controller.dart';
import '../../../core/formatting.dart';
import '../../../core/logging.dart';
import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';

/// The original audio, independent of transcription and AI availability.
class MeetingAudioPlayer extends ConsumerStatefulWidget {
  const MeetingAudioPlayer({
    super.key,
    required this.segments,
    required this.audioCleared,
  });
  final List<TranscriptSegment> segments;
  final bool audioCleared;
  @override
  ConsumerState<MeetingAudioPlayer> createState() => _MeetingAudioPlayerState();
}

class _MeetingAudioPlayerState extends ConsumerState<MeetingAudioPlayer> {
  AudioPlayer? _player;
  LocalPlayback? _owner;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<PlaybackClip> _clips = [];
  Duration _position = Duration.zero;
  bool _loading = false;
  String? _error;

  @override
  void didUpdateWidget(MeetingAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.audioCleared && !oldWidget.audioCleared) {
      _loading = false;
      _error = null;
      _position = Duration.zero;
      final player = _player;
      if (player != null) unawaited(player.stop().catchError(_fail));
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final player = _player;
    if (player != null) unawaited(_owner!.release(player));
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    final index = _player?.currentIndex ?? 0;
    if (_clips.isNotEmpty && index < _clips.length) {
      _position =
          Duration(milliseconds: _clips[index].startMs) +
          (_player?.position ?? Duration.zero);
    }
    setState(() {});
  }

  void _fail(Object error) {
    AppLog.e('audio.playback', 'local playback failed (${error.runtimeType})');
    if (mounted && !widget.audioCleared) {
      setState(() {
        _loading = false;
        _error = error is PlaybackUnavailable
            ? 'Část uloženého zvuku chybí nebo není úplná. Přepis a výpisky zůstávají dostupné.'
            : 'Zvuk nelze přehrát. Zkus to znovu; přepis a výpisky zůstávají uložené.';
      });
    }
  }

  Future<void> _toggle() async {
    final playback = ref.read(localPlaybackProvider);
    if (_loading ||
        widget.audioCleared ||
        playback.captureRequested ||
        ref.read(recordingControllerProvider).isRecording) {
      return;
    }
    try {
      if (_player?.playing == true) {
        await _player!.pause();
        return;
      }
      if (_player == null || _error != null) {
        setState(() {
          _loading = true;
          _error = null;
        });
        _clips = [
          for (final segment in widget.segments)
            PlaybackClip(
              path: segment.localAudioPath,
              startMs: segment.startMs,
              endMs: segment.endMs,
            ),
        ];
        final files = await resolvePlaybackFiles(_clips);
        final sources = [for (final file in files) AudioSource.uri(file)];
        if (!mounted ||
            widget.audioCleared ||
            playback.captureRequested ||
            ref.read(recordingControllerProvider).isRecording) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        if (_player == null) {
          _owner = ref.read(localPlaybackProvider);
          _player = _owner!.createPlayer();
          _subscriptions.addAll([
            _player!.positionStream.listen((_) => _update()),
            _player!.playerStateStream.listen((_) => _update()),
            _player!.currentIndexStream.listen((_) => _update()),
            _player!.errorStream.listen(_fail),
          ]);
        }
        await playback.prepare(() async {
          await _player!.setAudioSources(sources);
        });
        if (!mounted) return;
        setState(() => _loading = false);
      }
      if (widget.audioCleared ||
          ref.read(recordingControllerProvider).isRecording) {
        return;
      }
      await _owner!.pause(except: _player);
      if (!mounted || widget.audioCleared || playback.captureRequested) return;
      if (_player!.processingState == ProcessingState.completed) {
        await _player!.seek(Duration.zero, index: 0);
      }
      if (!mounted || widget.audioCleared || playback.captureRequested) return;
      unawaited(_player!.play().catchError(_fail));
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _seek(double ms) async {
    if (_player == null ||
        widget.audioCleared ||
        _loading ||
        ref.read(localPlaybackProvider).captureRequested ||
        ref.read(recordingControllerProvider).isRecording) {
      return;
    }
    final target = playbackLocation(_clips, Duration(milliseconds: ms.round()));
    try {
      await _player!.seek(target.position, index: target.index);
    } catch (error) {
      _fail(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(
      recordingControllerProvider.select((s) => s.isRecording),
    );
    final duration = widget.segments.isEmpty ? 0 : widget.segments.last.endMs;
    final unsupported =
        kIsWeb ||
        !const [
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform);
    final unavailable = widget.audioCleared || duration == 0 || unsupported;
    final text = recording
        ? 'Přehrávání bude dostupné po ukončení nahrávání.'
        : widget.audioCleared
        ? 'Zvuk byl uvolněn podle nastavení úložiště. Přepis zůstává.'
        : unsupported
        ? 'Přehrávání místního zvuku je dostupné v mobilní aplikaci.'
        : duration == 0
        ? 'Zvuk se objeví po uložení prvního úseku.'
        : _error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: _player?.playing == true
                    ? 'Pozastavit přehrávání'
                    : 'Přehrát nahrávku',
                onPressed: unavailable || recording || _loading
                    ? null
                    : _toggle,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _player?.playing == true
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zvuk hodiny',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${formatClock(_position)} / ${formatClockMs(duration)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (_error != null && !recording && !unavailable)
                TextButton(
                  onPressed: _toggle,
                  child: const Text('Zkusit znovu'),
                ),
            ],
          ),
          if (_player != null && !recording && !unavailable && _error == null)
            Slider(
              value: _position.inMilliseconds.toDouble().clamp(
                0,
                duration.toDouble(),
              ),
              max: duration.toDouble().clamp(1, double.infinity),
              label: formatClock(_position),
              semanticFormatterCallback: (value) =>
                  'Pozice ${formatClockMs(value.round())}',
              onChanged: _loading ? null : _seek,
            ),
          if (text != null)
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _error != null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
