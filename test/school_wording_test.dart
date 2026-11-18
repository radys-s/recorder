import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aftermind records school lessons. Texts a student reads must not call a
/// lesson a business meeting („schůzka"), and must name tabs that exist.
void main() {
  // lib/ai holds prompt examples that mention a meeting on purpose.
  // One line at a time and single-quoted strings only: a guard, not a proof.
  final uiFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.dart') &&
            !f.path.contains(
              '${Platform.pathSeparator}ai${Platform.pathSeparator}',
            ),
      );

  test('no user-facing string says schůzka', () {
    final offenders = <String>[];
    for (final file in uiFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        // Raw strings are patterns that still recognise titles older
        // recordings were given, not text anyone reads.
        if (RegExp(r"(?<!r)'[^']*[sS]chůzk[^']*'").hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: $line');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no text sends the student to a tab called Poznámky', () {
    final offenders = [
      for (final file in uiFiles)
        if (file.readAsStringSync().contains('záložce Poznámky')) file.path,
    ];
    expect(offenders, isEmpty);
  });
}
