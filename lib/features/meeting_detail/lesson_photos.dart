import '../../core/logging.dart';
import '../../core/photo_picker.dart';
import '../../data/db/daos/chat_messages_dao.dart';

/// Stores picked photos of the board or the slides as photo messages, one per
/// photo, in the order they were picked, and returns their ids.
///
/// They share one moment on the timeline: a gallery pick of five slides is one
/// act, and the id breaks the tie so they stay in picking order. A photo that
/// fails to store is skipped rather than costing the rest.
Future<({List<int> ids, int failed})> addLessonPhotos({
  required List<PickedPhoto> photos,
  required int meetingId,
  required int atMs,
  required Future<String> Function(PickedPhoto photo) store,
  required ChatMessagesDao chat,
}) async {
  final ids = <int>[];
  var failed = 0;
  for (final photo in photos) {
    try {
      final stored = await store(photo);
      ids.add(await chat.addPhotoMessage(
        meetingId: meetingId,
        imagePath: stored,
        atMs: atMs,
      ));
    } catch (e, st) {
      AppLog.e('chat.photo', 'lesson photo not stored', e, st);
      failed++;
    }
  }
  return (ids: ids, failed: failed);
}
