import 'package:drift/drift.dart';

/// Which model heard a refined window.
enum RefinedEngine { gemini, whisper }

enum RefinedStatus { pending, running, ready, failed }

/// The transcript made again after the lesson, from several minutes of audio
/// at a time rather than from 8-30 s chunks heard alone.
///
/// A window covers consecutive live chunks, so [startMs]/[endMs] are chunk
/// boundaries and a window replaces exactly the live segments inside it.
class RefinedSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get meetingId => integer()();
  IntColumn get windowIndex => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();

  /// Null until the window is ready; empty when the window held no speech.
  TextColumn get content => text().named('text').nullable()();
  TextColumn get engine => textEnum<RefinedEngine>()();
  IntColumn get status => intEnum<RefinedStatus>()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
