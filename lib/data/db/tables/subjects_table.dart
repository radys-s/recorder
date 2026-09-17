import 'package:drift/drift.dart';

/// A school subject — „Čeština", „Dějepis" — and, for everything that is not
/// school, simply a folder of saved notes.
///
/// Lives in the `note_folders` table on purpose: subjects replaced the note
/// folders of schema v9, and extending that table in place kept every folder
/// id the user's saved notes already point at. No row copy, no id remapping.
@DataClassName('Subject')
class Subjects extends Table {
  @override
  String get tableName => 'note_folders';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  DateTimeColumn get createdAt => dateTime()();

  /// How the AI should answer in this subject. Sits between the global rules
  /// and a single lesson's rules; the more specific level wins.
  TextColumn get rules => text().nullable()();

  /// Index into the fixed subject palette, so the colour follows the theme
  /// instead of being a stored RGB value that is wrong in dark mode.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// The subject's full name when [name] is a short label — „PSI" is
  /// „Počítačové sítě".
  TextColumn get fullName => text().nullable()();

  /// A level that differs from the course's year, e.g. „2. ročník" for a
  /// seminar shared with a younger class.
  TextColumn get levelOverride => text().nullable()();
}
