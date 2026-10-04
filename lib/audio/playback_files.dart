import 'dart:io';

import '../core/paths.dart';
import 'playback_timeline.dart';

enum PlaybackUnavailableReason { incompleteTimeline, missingFile, emptyFile }

class PlaybackUnavailable implements Exception {
  const PlaybackUnavailable(this.reason);
  final PlaybackUnavailableReason reason;
}

/// Verify the whole playlist before playing; a missing chunk must not silently
/// shorten a lesson or shift the transcript timestamps. Never modifies files.
Future<List<Uri>> resolvePlaybackFiles(List<PlaybackClip> clips) async {
  if (!isContinuousPlayback(clips)) {
    throw const PlaybackUnavailable(
      PlaybackUnavailableReason.incompleteTimeline,
    );
  }
  final files = <Uri>[];
  for (final clip in clips) {
    final file = File(await resolveStoredPath(clip.path));
    if (!await file.exists()) {
      throw const PlaybackUnavailable(PlaybackUnavailableReason.missingFile);
    }
    if (await file.length() <= 44) {
      throw const PlaybackUnavailable(PlaybackUnavailableReason.emptyFile);
    }
    files.add(file.uri);
  }
  return files;
}
