import 'package:drift/drift.dart';

enum ChatRole { user, assistant }

/// What a message typed during a lesson is for.
/// Stored by name. [important] is a ⭐ the student put on a moment.
enum ChatIntent { context, question, rule, photo, answerNow, important }

enum ChatStatus { pending, ready, failed }

/// The chat that runs alongside a recording: context and rules the student
/// types, questions asked directly, and the AI's replies.
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get meetingId => integer()();
  TextColumn get role => textEnum<ChatRole>()();
  TextColumn get intent => textEnum<ChatIntent>()();

  /// `text` would shadow the column builder inside a table class.
  TextColumn get body => text().named('text').withDefault(const Constant(''))();
  TextColumn get imagePath => text().nullable()();

  /// Offset into the recording, so the message sorts into the transcript.
  IntColumn get atMs => integer()();
  IntColumn get status => intEnum<ChatStatus>()();

  /// An assistant reply: one bold line, then the explanation.
  TextColumn get short => text().nullable()();
  TextColumn get detail => text().nullable()();
  TextColumn get basis => text().nullable()();
  TextColumn get sources => text().nullable()();
  IntColumn get replyTo => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}
