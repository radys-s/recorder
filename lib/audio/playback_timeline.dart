/// A chunk on the recording's audio timeline, including untranscribed silence.
class PlaybackClip {
  const PlaybackClip({
    required this.path,
    required this.startMs,
    required this.endMs,
  });
  final String path;
  final int startMs;
  final int endMs;
}

/// Maps a lesson seek to a chunk-local seek, without concatenating large WAVs.
({int index, Duration position}) playbackLocation(
  List<PlaybackClip> clips,
  Duration at,
) {
  if (clips.isEmpty) throw StateError('No audio clips');
  final ms = at.inMilliseconds.clamp(0, clips.last.endMs);
  for (var i = 0; i < clips.length; i++) {
    if (ms < clips[i].endMs || i == clips.length - 1) {
      return (
        index: i,
        position: Duration(
          milliseconds: (ms - clips[i].startMs).clamp(
            0,
            clips[i].endMs - clips[i].startMs,
          ),
        ),
      );
    }
  }
  throw StateError('Unreachable');
}

bool isContinuousPlayback(List<PlaybackClip> clips) {
  var end = 0;
  for (final clip in clips) {
    if (clip.startMs != end || clip.endMs <= clip.startMs) return false;
    end = clip.endMs;
  }
  return clips.isNotEmpty;
}
