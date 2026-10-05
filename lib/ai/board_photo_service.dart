import 'dart:io';
import 'dart:typed_data';

import '../core/logging.dart';
import '../core/photo_files.dart';
import '../data/db/daos/chat_messages_dao.dart';
import '../data/db/tables/chat_messages_table.dart';
import 'gemini_provider.dart';
import 'photo_questions.dart';
import 'photo_text_service.dart';

/// Turns a board photo in the lesson chat into lesson context.
///
/// The photo row is stored first, pending, so the bubble shows the picture
/// straight away and a killed app leaves a visible failure. Once read, its
/// text is context like anything typed. When the photo carries questions (a
/// worksheet, a task on the board) they are answered right away, as a reply
/// under the photo; a failed answer never costs the text that was read.
class BoardPhotoService {
  BoardPhotoService(
    this._chat,
    this._reader, {
    required this._readBytes,
    this._subjectName,
    this._answer,
  });

  static const _tag = 'ai.photos.board';

  final ChatMessagesDao _chat;
  final PhotoTextService _reader;

  /// Bytes of a stored (relative) photo path.
  final Future<Uint8List> Function(String storedPath) _readBytes;
  final Future<String?> Function(int meetingId)? _subjectName;

  /// Answers the questions on a read photo (`ChatAnswerService.askAboutPhoto`).
  final Future<void> Function(int photoMessageId, List<String> questions)?
  _answer;
  final _inFlight = <int>{};

  /// Reads photo message [messageId], again if it failed. True when read.
  /// Never throws.
  Future<bool> read(int messageId) async {
    if (!_inFlight.add(messageId)) return false;
    try {
      final message = await _chat.message(messageId);
      final path = message?.imagePath;
      if (message == null ||
          message.intent != ChatIntent.photo ||
          path == null) {
        return false;
      }
      if (message.status != ChatStatus.pending) {
        await _chat.markPending(messageId);
      }

      try {
        final bytes = await _readBytes(path);
        final subject = await _subjectName?.call(message.meetingId);
        final reading = await _reader.readBoard(
          LlmImage(bytes, mimeType: photoMimeType(path)),
          subjectName: subject,
        );
        await _chat.completePhoto(
          messageId,
          text: reading.text,
          description: reading.description,
        );
        AppLog.d(
          _tag,
          'photo $messageId read: ${reading.text.length} chars of text',
        );
        final questions = reading.questions.isNotEmpty
            ? reading.questions
            : extractQuestions(reading.text);
        if (questions.isNotEmpty) await _answerQuietly(messageId, questions);
        return true;
      } catch (e, st) {
        AppLog.e(_tag, 'photo $messageId not read', e, st);
        await _chat.failPhoto(
          messageId,
          e is FileSystemException ? 'Fotka se nenašla.' : geminiFailureText(e),
        );
        return false;
      }
    } catch (e, st) {
      AppLog.e(_tag, 'photo $messageId: bookkeeping failed', e, st);
      return false;
    } finally {
      _inFlight.remove(messageId);
    }
  }

  /// Answers the questions on the already read photo [messageId] (again if the
  /// first try failed). Questions come from the stored text; with none found
  /// the whole text goes to the model, which finds them itself. Never throws.
  Future<void> answerQuestions(int messageId) async {
    try {
      final message = await _chat.message(messageId);
      if (message == null ||
          message.intent != ChatIntent.photo ||
          message.status != ChatStatus.ready) {
        return;
      }
      await _answerQuietly(messageId, extractQuestions(message.body));
    } catch (e, st) {
      AppLog.e(_tag, 'photo $messageId: answering failed', e, st);
    }
  }

  Future<void> _answerQuietly(int messageId, List<String> questions) async {
    final answer = _answer;
    if (answer == null) return;
    try {
      await answer(messageId, questions);
    } catch (e, st) {
      AppLog.e(_tag, 'photo $messageId: answer failed', e, st);
    }
  }
}
