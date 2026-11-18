import 'dart:io';

import 'package:recorder/data/recovery_backup.dart';

/// Offline verification / recovery on a computer. Never opens the app, asks an
/// AI service, or replaces an existing directory. Keep private archives out of Git.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/restore_backup.dart BACKUP.zip NEW_DIRECTORY',
    );
    exitCode = 64;
    return;
  }
  try {
    await RecoveryBackup.restore(
      backup: File(args[0]),
      destination: Directory(args[1]),
    );
    stdout.writeln('Restoration verified. No application was started.');
  } catch (error) {
    stderr.writeln(
      error is FormatException
          ? error.message
          : 'Restoration failed (${error.runtimeType}).',
    );
    exitCode = 1;
  }
}
