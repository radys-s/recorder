import 'dart:io';

import '../core/logging.dart';
import '../core/paths.dart';
import 'db/daos/meetings_dao.dart';

/// Deleting a meeting for good: its rows, then its audio.
///
/// The database goes first. Once it has committed the meeting is gone from
/// every screen, and a directory that fails to delete afterwards is only disk
/// space — whereas files deleted first and a transaction that then fails would
/// leave a transcript pointing at audio that no longer exists.
class MeetingDeleter {
  MeetingDeleter(
    this._meetings, {
    required this._isRecording,
    required this._documentsPath,
  });

  static const _tag = 'meetings.delete';

  final MeetingsDao _meetings;
  final bool Function(int meetingId) _isRecording;
  final Future<String> Function() _documentsPath;

  /// Throws [StateError] for the meeting being recorded right now: the
  /// recorder would keep writing chunks into a directory and rows that no
  /// longer exist. The UI disables the action in that case; this is the
  /// guarantee behind it.
  Future<void> delete(int meetingId) async {
    if (_isRecording(meetingId)) {
      throw StateError('meeting $meetingId is being recorded');
    }

    await _meetings.deleteMeeting(meetingId);
    AppLog.d(_tag, 'meeting $meetingId deleted');

    try {
      final dir = Directory(
        meetingRecordingsDir(await _documentsPath(), meetingId),
      );
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: audio not removed', e, st);
    }
  }
}
