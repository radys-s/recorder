import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/logging.dart';
import '../core/paths.dart';
import 'db/daos/meetings_dao.dart';
import 'db/daos/preferences_dao.dart';
import 'db/tables/preferences_table.dart';

/// Whether a finished lesson's chunk files can go.
///
/// Three things have to be true, and each of them is somebody's work that
/// would be lost otherwise: the retention window has passed, every chunk has
/// been transcribed or given up on, and the refined pass is no longer waiting
/// to re-hear the recording.
bool canClearAudio({
  required ClearableAudio meeting,
  required AudioRetention retention,
  required DateTime now,
}) {
  final keepFor = retention.keepFor;
  if (keepFor == null) return false;
  if (!meeting.queueSettled || !meeting.refiningSettled) return false;
  return !now.isBefore(meeting.endedAt.add(keepFor));
}

/// How much space one lesson's audio takes. Zero for a lesson whose files are
/// already gone, which is also what a missing directory means.
Future<int> directorySize(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return 0;
  var bytes = 0;
  await for (final entry in dir.list(recursive: true, followLinks: false)) {
    if (entry is File) {
      try {
        bytes += await entry.length();
      } on FileSystemException {
        // Deleted between listing and measuring: it is not taking space.
      }
    }
  }
  return bytes;
}

/// One lesson's audio on disk, for the storage screen.
class MeetingAudioSize {
  const MeetingAudioSize({
    required this.meetingId,
    required this.title,
    required this.bytes,
  });

  final int meetingId;
  final String title;
  final int bytes;
}

/// Deletes the audio of lessons that no longer need it.
///
/// Chunk WAVs are the only thing in the app that grows without bound — about
/// 1.9 MB a minute, so a school week is a gigabyte or two. Everything the
/// student actually reads (transcript, refined transcript, výpisky, answers)
/// is in the database and is never touched here.
class AudioCleaner {
  AudioCleaner(
    this._meetings,
    this._preferences, {
    required this.documentsPath,
    bool Function(int meetingId)? isRecording,
  }) : _isRecording = isRecording ?? _notRecording;

  static const _tag = 'audio.cleanup';
  static bool _notRecording(int _) => false;

  final MeetingsDao _meetings;
  final PreferencesDao _preferences;

  /// Where the app's files live. A function, because on iOS the container
  /// path is only stable within a run.
  final Future<String> Function() documentsPath;
  final bool Function(int meetingId) _isRecording;

  /// Deletes what is due and returns how many lessons were freed.
  ///
  /// With [force] the retention window is ignored — that is „Uvolnit místo
  /// teď", where the student has asked for the space back now. The other two
  /// conditions still hold, because they are about losing a transcript rather
  /// than about waiting.
  Future<int> sweep({DateTime? now, bool force = false}) async {
    final prefs = await _preferences.current();
    final retention = force ? AudioRetention.oneDay : prefs.audioRetention;
    if (!force && retention == AudioRetention.never) return 0;

    final at = now ?? DateTime.now();
    final candidates = await _meetings.clearableAudio();
    var cleared = 0;
    String? docs;

    for (final meeting in candidates) {
      if (_isRecording(meeting.meetingId)) continue;
      final due = force
          ? meeting.queueSettled && meeting.refiningSettled
          : canClearAudio(meeting: meeting, retention: retention, now: at);
      if (!due) continue;

      try {
        docs ??= await documentsPath();
        final dir = meetingRecordingsDir(docs, meeting.meetingId);
        final dirHandle = Directory(dir);
        if (await dirHandle.exists()) {
          await dirHandle.delete(recursive: true);
        }
        // The row is marked even when there was nothing to delete: the audio
        // is gone either way, and „Přepsat znovu" has to say so.
        await _meetings.markAudioCleared(meeting.meetingId, at);
        cleared++;
      } catch (e, st) {
        AppLog.e(_tag, 'meeting ${meeting.meetingId}: audio kept', e, st);
      }
    }

    if (cleared > 0) AppLog.d(_tag, 'cleared audio of $cleared meetings');
    return cleared;
  }

  /// Every lesson that still has audio, biggest first.
  Future<List<MeetingAudioSize>> sizes() async {
    final docs = await documentsPath();
    final root = Directory(p.join(docs, kRecordingsDirName));
    if (!await root.exists()) return const [];

    final titles = {
      for (final m in await _meetings.allMeetingsOnce()) m.id: m.title,
    };
    final sizes = <MeetingAudioSize>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      final id = int.tryParse(name.replaceFirst('meeting_', ''));
      if (id == null) continue;
      final bytes = await directorySize(entry.path);
      if (bytes == 0) continue;
      sizes.add(
        MeetingAudioSize(
          meetingId: id,
          title: titles[id] ?? 'Smazaná schůzka',
          bytes: bytes,
        ),
      );
    }
    sizes.sort((a, b) => b.bytes.compareTo(a.bytes));
    return sizes;
  }
}

/// „85 MB" — the unit a person thinks in, not bytes.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['kB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  // A decimal only where it still says something: „1.4 GB" is a
  // different amount of free space, „85.0 MB" is just noise.
  final digits = value >= 10 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
