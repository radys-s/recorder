import 'package:drift/drift.dart';

enum SegmentStatus { pending, uploading, transcribed, failed }

/// One audio chunk of a meeting and its transcription state. Rows are
/// inserted at chunk-finalize time regardless of network state, so
/// "transcript so far, mid-recording" already works by construction.
class TranscriptSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get meetingId => integer()();
  IntColumn get sequence => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get content => text().nullable()();
  IntColumn get status => intEnum<SegmentStatus>()();
  TextColumn get localAudioPath => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// How much of the chunk sounded like speech when it was recorded. Lets the
  /// worker reject a transcript far longer than the speech it came from;
  /// null for rows written before v12, which skip that check.
  IntColumn get voicedMs => integer().nullable()();

  /// What was heard before the user or the AI changed [content]; null while
  /// the text is untouched.
  TextColumn get rawContent => text().nullable()();

  /// How sure Whisper was: the duration-weighted mean `avg_logprob` of the
  /// segments it kept. Null when it reported none, or for rows before v17.
  RealColumn get confidence => real().nullable()();

  /// How the PCM chunk ended. Null only for rows written before v22.
  TextColumn get cutReason => text().nullable()();

  /// Which engine wrote [content] (`groq-large`, `groq-turbo`, `gemini`), for
  /// the problem report. Null before v27 or while nothing is written.
  TextColumn get sttEngine => text().nullable()();

  /// The Whisper segment filter's limits as they stood when the chunk was
  /// recorded. The room may have changed by the time it is uploaded, and a
  /// backlog can be uploaded minutes later; null before v27.
  RealColumn get noSpeechThreshold => real().nullable()();
  RealColumn get lowLogprobThreshold => real().nullable()();
}
