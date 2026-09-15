import 'package:drift/drift.dart';

/// Where a card's content came from.
enum CardKind { text, photo, lookup, lesson }

/// Saved material a subject keeps coming back to — a book, a period, a topic —
/// that the live answers can draw on during a lesson.
class ContextCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get kind => textEnum<CardKind>()();

  /// The full text, always editable by the user.
  TextColumn get content => text().withDefault(const Constant(''))();

  /// A short digest (≤ 600 chars) sent when the token budget is tight. Null
  /// until one is generated; the context builder falls back to the content.
  TextColumn get summary => text().nullable()();

  /// Names and terms, comma-separated — also used as a Whisper glossary.
  TextColumn get keywords => text().nullable()();

  /// JSON `[{title, url}]`, the same shape as `answer_cards.sources`.
  TextColumn get sources => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
}

/// Page photos a card was built from, stored as paths relative to documents.
class CardImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId => integer()();
  TextColumn get path => text()();
  IntColumn get ord => integer().withDefault(const Constant(0))();
}

/// Cards pinned for one lesson — always part of its AI context.
class MeetingCards extends Table {
  IntColumn get meetingId => integer()();
  IntColumn get cardId => integer()();

  @override
  Set<Column> get primaryKey => {meetingId, cardId};
}

/// A weekly timetable slot that preselects a subject when recording starts.
class TimetableSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer()();

  /// 1 = Monday … 7 = Sunday, as `DateTime.weekday`.
  IntColumn get weekday => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();
}
