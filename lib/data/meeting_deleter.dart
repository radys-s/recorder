import '../core/logging.dart';
import '../core/paths.dart';
import '../core/photo_files.dart';
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
      final docs = await _documentsPath();
      await removeDirectory(meetingRecordingsDir(docs, meetingId));
      // Board photos from the lesson chat. A card saved from one has its own
      // copy under cards/, so nothing a card shows goes with the meeting.
      await removeDirectory(meetingPhotosDir(docs, meetingId));
    } catch (e, st) {
      AppLog.e(_tag, 'meeting $meetingId: files not removed', e, st);
    }
  }
}
