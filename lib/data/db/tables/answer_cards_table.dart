import 'package:drift/drift.dart';

/// One question heard at a meeting and the answer the model gave for it.
///
/// A row exists only once the model has confirmed the passage really was a
/// question, so a false positive from the cheap pre-filter leaves no trace
/// here — nothing the user sees is ever a guess about whether they were asked
/// something.
class AnswerCards extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get meetingId => integer()();

  /// The transcript segment the question was heard in. The card is rendered
  /// directly after that segment, so the answer sits where the question was
  /// asked rather than at the end of the timeline.
  IntColumn get segmentId => integer()();

  TextColumn get question => text()();
  TextColumn get answer => text()();

  /// Where the answer came from: `meeting` when it is in what was said,
  /// `knowledge` when the model answered from its own general knowledge,
  /// `unknown` when neither could settle it, and `web` when it was looked up
  /// on the internet.
  ///
  /// `web` is the only one the app writes rather than the model: it is set
  /// after a successful web hop, so it cannot be produced by a model that
  /// merely claims to have searched.
  ///
  /// Stored as text rather than an enum because it is a label from the model,
  /// not a value the app branches on — an unrecognised one renders as no badge
  /// instead of crashing a screen mid-meeting. The badge exists because the
  /// user's standing rule is that the app must not put words in their mouth:
  /// an answer that comes from outside the room has to say so.
  TextColumn get basis =>
      text().withLength(min: 0, max: 20).withDefault(const Constant('meeting'))();

  /// The pages a `web` answer was drawn from: a JSON array of
  /// `{title, url}`, capped at three, or null when there are none.
  ///
  /// JSON in a column rather than a table of its own — nothing ever queries
  /// across sources, and a nullable column is the whole migration for every
  /// card written before web answers existed.
  TextColumn get sources => text().nullable()();

  /// Set by the close button on the pinned panel. Dismissing hides the panel,
  /// never the timeline card — the answer stays part of the meeting's record.
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
}
