import '../core/logging.dart';
import '../core/photo_files.dart';
import 'db/daos/subjects_dao.dart';

/// Deleting cards for good: their rows, then their page photos.
///
/// Database first, files after, for the reason `MeetingDeleter` gives: a
/// directory left behind is only disk space, a card pointing at deleted
/// photos is a broken screen.
class CardDeleter {
  CardDeleter(this._cards, {required this._documentsPath});

  static const _tag = 'cards.delete';

  final SubjectsDao _cards;
  final Future<String> Function() _documentsPath;

  Future<void> deleteCard(int cardId) async {
    await _cards.deleteCard(cardId);
    await _removePhotos([cardId]);
  }

  /// The subject with its cards; notes and lessons stay (see
  /// `SubjectsDao.deleteSubject`).
  Future<void> deleteSubject(int subjectId) async {
    final ids = [for (final c in await _cards.cards(subjectId)) c.id];
    await _cards.deleteSubject(subjectId);
    await _removePhotos(ids);
  }

  Future<void> _removePhotos(List<int> cardIds) async {
    if (cardIds.isEmpty) return;
    try {
      final docs = await _documentsPath();
      for (final id in cardIds) {
        await removeDirectory(cardPhotosDir(docs, id));
      }
    } catch (e, st) {
      AppLog.e(_tag, 'cards $cardIds: photos not removed', e, st);
    }
  }
}
