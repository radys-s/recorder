import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/drive_docs_table.dart';

part 'drive_docs_dao.g.dart';

@DriftAccessor(tables: [DriveDocs])
class DriveDocsDao extends DatabaseAccessor<AppDatabase>
    with _$DriveDocsDaoMixin {
  DriveDocsDao(super.db);

  Stream<List<DriveDoc>> watchAll() => select(driveDocs).watch();

  Future<DriveDoc?> doc(int subjectId, DriveDocKind kind) =>
      (select(driveDocs)..where(
            (t) => t.subjectId.equals(subjectId) & t.kind.equalsValue(kind),
          ))
          .getSingleOrNull();

  /// Records a successful upload: the doc now holds [hash].
  Future<void> markSynced(
    int subjectId,
    DriveDocKind kind, {
    required String docId,
    required String hash,
    required DateTime at,
  }) => into(driveDocs).insertOnConflictUpdate(
    DriveDocsCompanion.insert(
      subjectId: subjectId,
      kind: kind,
      docId: Value(docId),
      syncedAt: Value(at),
      contentHash: Value(hash),
      error: const Value(null),
    ),
  );

  /// Keeps the doc id and the last good upload; only the error changes.
  Future<void> markFailed(int subjectId, DriveDocKind kind, String error) =>
      transaction(() async {
        final existing = await doc(subjectId, kind);
        if (existing == null) {
          await into(driveDocs).insert(
            DriveDocsCompanion.insert(
              subjectId: subjectId,
              kind: kind,
              error: Value(error),
            ),
          );
        } else {
          await (update(driveDocs)..where(
                (t) => t.subjectId.equals(subjectId) & t.kind.equalsValue(kind),
              ))
              .write(DriveDocsCompanion(error: Value(error)));
        }
      });

  /// Forgets a doc that no longer exists in Drive, so the next sync creates
  /// a new one.
  Future<void> forget(int subjectId, DriveDocKind kind) =>
      (delete(driveDocs)..where(
            (t) => t.subjectId.equals(subjectId) & t.kind.equalsValue(kind),
          ))
          .go();

  /// Forgets every doc — the Drive folder is gone, so they went with it.
  Future<void> forgetAll() => delete(driveDocs).go();
}
