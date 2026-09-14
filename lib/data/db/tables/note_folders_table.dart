import 'package:drift/drift.dart';

/// A folder in the saved-notes library — „Čeština", „Práce".
///
/// Flat on purpose: one level is what people actually sort notes into, and a
/// tree would need a navigation model the library does not otherwise have.
class NoteFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  DateTimeColumn get createdAt => dateTime()();
}
