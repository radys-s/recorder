import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Lazily owned players. Capture pauses them before opening the microphone, because
/// both plugins share the iOS audio session. Playback never changes stored data.
class LocalPlayback {
  final _players = <AudioPlayer>{};
  final _preparations = <Future<void>>{};
  bool captureRequested = false;
  Future<void> suspendForCapture() async {
    captureRequested = true;
    // Preparing a playlist can activate the shared audio session too. Let an
    // in-flight preparation settle before pausing and opening the microphone.
    for (final preparation in _preparations.toList()) {
      try {
        await preparation;
      } catch (_) {
        // The player reports its own loading failure; capture remains usable.
      }
    }
    await pause();
  }

  Future<void> prepare(Future<void> Function() operation) async {
    final preparation = operation();
    _preparations.add(preparation);
    try {
      await preparation;
    } finally {
      _preparations.remove(preparation);
    }
  }

  void releaseCapture() => captureRequested = false;
  AudioPlayer createPlayer() {
    final player = AudioPlayer();
    _players.add(player);
    return player;
  }

  Future<void> pause({AudioPlayer? except}) async {
    for (final player in _players.toList()) {
      if (player != except) await player.pause();
    }
  }

  Future<void> release(AudioPlayer player) async {
    _players.remove(player);
    await player.dispose();
  }

  Future<void> dispose() async {
    for (final player in _players.toList()) {
      await release(player);
    }
  }
}

final localPlaybackProvider = Provider<LocalPlayback>((ref) {
  final playback = LocalPlayback();
  ref.onDispose(playback.dispose);
  return playback;
});
