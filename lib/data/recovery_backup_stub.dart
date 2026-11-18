import 'dart:io';

/// Web previews cannot access the mobile documents directory or native SQLite.
class RecoveryBackup {
  static Future<File> create({
    required Directory documents,
    required File destination,
    required Future<void> Function(String path) snapshotTo,
  }) async =>
      throw UnsupportedError('Záloha zvuku je dostupná v mobilní aplikaci.');
}
