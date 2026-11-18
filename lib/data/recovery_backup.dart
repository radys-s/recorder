import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/redaction.dart';

/// Offline recovery, not a text export or sync. Never overwrites a destination,
/// opens the live database, reads credentials, or starts processing restored data.
/// The caller snapshots SQLite with VACUUM INTO while capture is stopped.
class RecoveryBackup {
  static const databaseName = 'recorder.sqlite';
  static const _manifestName = 'manifest.json';
  static const _roots = {'recordings', 'photos', 'cards'};
  static const _maxBytes = 32 * 1024 * 1024 * 1024;

  static bool _safeName(String name) {
    if (name == databaseName || name == _manifestName) return true;
    final parts = name.split('/');
    return parts.length >= 2 &&
        _roots.contains(parts.first) &&
        parts.every(
          (s) =>
              s.isNotEmpty &&
              s != '.' &&
              s != '..' &&
              !s.endsWith('.') &&
              !s.endsWith(' ') &&
              !RegExp(r'[\\:<>"|?*\x00-\x1f]').hasMatch(s) &&
              !RegExp(
                r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)',
                caseSensitive: false,
              ).hasMatch(s),
        );
  }

  static Future<String> _hash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<void> _requireAbsent(String path) async {
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const FormatException(
        'Cílové umístění už existuje. Nic nebylo přepsáno.',
      );
    }
  }

  /// Includes every local media file, including recovery checkpoints. Snapshot
  /// paths are rewritten only in the copy, never in the user's live database.
  static Future<File> create({
    required Directory documents,
    required File destination,
    required Future<void> Function(String path) snapshotTo,
  }) async {
    await _requireAbsent(destination.path);
    final docs = await documents.resolveSymbolicLinks();
    if (p.isWithin(docs, p.absolute(destination.path))) {
      throw const FormatException('Záloha musí být mimo původní data.');
    }
    await destination.parent.create(recursive: true);
    final stage = await destination.parent.createTemp('aftermind-backup-');
    try {
      await snapshotTo(p.join(stage.path, databaseName));
      // Compression, checksums and trial restoration must not freeze controls
      // while a long lesson is being backed up. Only SQLite snapshotting uses
      // the caller's connection; all heavy file work owns a separate isolate.
      final stagePath = stage.path;
      final destinationPath = destination.path;
      return await _offThread(docs, stagePath, destinationPath);
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  // Keep the isolate closure separate from the live DB callback's scope.
  static Future<File> _offThread(
    String docs,
    String stage,
    String destination,
  ) => Isolate.run(() => _package(docs, stage, destination));

  static Future<File> _package(
    String docs,
    String stagePath,
    String destinationPath,
  ) async {
    final stage = Directory(stagePath);
    final destination = File(destinationPath);
    final partial = File('$stagePath.zip');
    try {
      for (final root in _roots) {
        final directory = Directory(p.join(docs, root));
        if (await FileSystemEntity.type(directory.path, followLinks: false) ==
            FileSystemEntityType.link) {
          throw const FormatException('Záloha nepodporuje symbolické odkazy.');
        }
        if (!await directory.exists()) continue;
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is Link) {
            throw const FormatException(
              'Záloha nepodporuje symbolické odkazy.',
            );
          }
          if (entity is! File) continue;
          final name = p.posix.joinAll(
            p.split(p.relative(entity.path, from: docs)),
          );
          if (!_safeName(name)) {
            throw const FormatException('Neplatná cesta souboru.');
          }
          final copy = File(p.join(stage.path, p.joinAll(name.split('/'))));
          await copy.parent.create(recursive: true);
          await entity.copy(copy.path);
          if (await _hash(entity) != await _hash(copy)) {
            throw const FormatException(
              'Data se během zálohování změnila. Zkus zálohu znovu.',
            );
          }
        }
      }
      _portableSnapshot(stage, docs);
      await _verifyDatabase(stage);
      final entries = <String, Object>{};
      await for (final entity in stage.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final name = p.posix.joinAll(
          p.split(p.relative(entity.path, from: stage.path)),
        );
        entries[name] = {
          'bytes': await entity.length(),
          'sha256': await _hash(entity),
        };
      }
      await File(p.join(stage.path, _manifestName)).writeAsString(
        jsonEncode({
          'format': 'aftermind-recovery',
          'version': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'files': entries,
        }),
        flush: true,
      );
      final encoder = ZipFileEncoder()..create(partial.path);
      try {
        // Only files belong in the manifest. Directory entries emitted by
        // zipDirectory would fail our intentionally strict restore contract.
        for (final name in [...entries.keys, _manifestName]) {
          await encoder.addFile(
            File(p.join(stage.path, p.joinAll(name.split('/')))),
            name,
          );
        }
      } finally {
        await encoder.close();
      }
      // Restore the actual ZIP to an isolated copy before calling it a backup.
      final check = Directory('${stage.path}-verify');
      try {
        await restore(backup: partial, destination: check);
      } finally {
        if (await check.exists()) await check.delete(recursive: true);
      }
      await _requireAbsent(destination.path);
      return await partial.rename(destination.path);
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  static void _portableSnapshot(Directory stage, String docs) {
    final db = sqlite3.open(p.join(stage.path, databaseName));
    try {
      for (final (table, column) in const [
        ('transcript_segments', 'local_audio_path'),
        ('upload_queue', 'local_file_path'),
        ('chat_messages', 'image_path'),
        ('card_images', 'path'),
      ]) {
        for (final row in db.select(
          'SELECT rowid AS rid, "$column" AS path FROM "$table"',
        )) {
          final original = row['path'] as String?;
          if (original == null || original.isEmpty) continue;
          var name = original;
          if (p.isAbsolute(original)) {
            if (!p.isWithin(docs, original)) {
              throw const FormatException(
                'Soubor mimo data aplikace nelze bezpečně zálohovat.',
              );
            }
            name = p.posix.joinAll(p.split(p.relative(original, from: docs)));
          }
          if (!_safeName(name) || !_roots.contains(name.split('/').first)) {
            throw const FormatException('Neplatná cesta v databázi.');
          }
          db.execute('UPDATE "$table" SET "$column" = ? WHERE rowid = ?', [
            name,
            row['rid'],
          ]);
        }
      }
      // Historic server errors can contain an echoed credential. Sanitize only
      // error columns in the snapshot, never the original or users' lesson text.
      for (final table in db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )) {
        final name = table['name'] as String;
        final quoted = '"${name.replaceAll('"', '""')}"';
        for (final col in db.select('PRAGMA table_info($quoted)')) {
          final column = col['name'] as String;
          if (!column.toLowerCase().endsWith('error')) continue;
          final field = '"${column.replaceAll('"', '""')}"';
          for (final row in db.select(
            'SELECT rowid AS rid, $field AS error FROM $quoted WHERE $field IS NOT NULL',
          )) {
            final error = row['error'];
            if (error is String) {
              db.execute('UPDATE $quoted SET $field = ? WHERE rowid = ?', [
                redactSecrets(error),
                row['rid'],
              ]);
            }
          }
        }
      }
    } finally {
      db.close();
    }
  }

  static Future<void> _verifyDatabase(Directory restored) async {
    final file = File(p.join(restored.path, databaseName));
    if (!await file.exists()) {
      throw const FormatException('Záloha neobsahuje databázi.');
    }
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      if (db.select('PRAGMA integrity_check').single.values.single != 'ok' ||
          db.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const FormatException('Databáze v záloze není úplná.');
      }
      // Detect a missing audio chunk, rather than producing a valid ZIP that
      // only contains text. Intentionally cleared audio remains cleared.
      for (final row in db.select('''
        SELECT s.local_audio_path AS path FROM transcript_segments s
        JOIN meetings m ON m.id = s.meeting_id WHERE m.audio_cleared_at IS NULL
        UNION SELECT q.local_file_path AS path FROM upload_queue q
        JOIN meetings m ON m.id = q.meeting_id WHERE m.audio_cleared_at IS NULL
        UNION SELECT image_path AS path FROM chat_messages WHERE image_path IS NOT NULL
        UNION SELECT path FROM card_images
      ''')) {
        final name = row['path'] as String;
        if (!_safeName(name) || !_roots.contains(name.split('/').first)) {
          throw const FormatException('Záloha obsahuje nepřenositelnou cestu.');
        }
        if (!await File(p.join(restored.path, p.joinAll(name.split('/'))))
            .exists()) {
          throw const FormatException('V záloze chybí zvuk nebo fotografie.');
        }
      }
    } finally {
      db.close();
    }
  }

  /// Restores into a NEW directory only. Everything is verified in a sibling
  /// staging directory; failures never leave a partly restored destination.
  static Future<void> restore({
    required File backup,
    required Directory destination,
  }) async {
    await _requireAbsent(destination.path);
    await destination.parent.create(recursive: true);
    final stage = await destination.parent.createTemp('aftermind-restore-');
    InputFileStream? input;
    try {
      input = InputFileStream(backup.path);
      // Validate central headers BEFORE decodeStream reads symbolic-link data.
      // The decoder would otherwise allocate it before our path/size guards.
      final directory = ZipDirectory()..read(input);
      final headerNames = <String>{};
      var headerBytes = 0;
      for (final header in directory.fileHeaders) {
        headerBytes += header.uncompressedSize;
        if (!_safeName(header.filename) ||
            !headerNames.add(header.filename.toLowerCase()) ||
            ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000 ||
            header.uncompressedSize < 0 ||
            headerBytes > _maxBytes ||
            directory.fileHeaders.length > 100000) {
          throw const FormatException(
            'Neplatný nebo příliš velký archiv zálohy.',
          );
        }
      }
      input.setPosition(0);
      final decoder = ZipDecoder();
      final archive = decoder.decodeStream(input);
      final names = <String>{};
      var bytes = 0;
      for (final entry in archive) {
        bytes += entry.size;
        if (!_safeName(entry.name) ||
            !entry.isFile ||
            entry.isSymbolicLink ||
            !names.add(entry.name.toLowerCase()) ||
            entry.size < 0 ||
            bytes > _maxBytes ||
            archive.length > 100000) {
          throw const FormatException(
            'Neplatný nebo příliš velký archiv zálohy.',
          );
        }
      }
      // The decoder coalesces repeated ZIP names: reject those at the headers.
      if (decoder.directory.fileHeaders.length != archive.length) {
        throw const FormatException('Duplicitní soubor v záloze.');
      }
      final manifestEntry = archive.find(_manifestName);
      if (manifestEntry == null || manifestEntry.size > 8 * 1024 * 1024) {
        throw const FormatException('Chybí seznam souborů zálohy.');
      }
      final manifestFile = File(p.join(stage.path, _manifestName));
      await _writeEntry(manifestEntry, manifestFile);
      final manifest = jsonDecode(await manifestFile.readAsString());
      if (manifest is! Map ||
          manifest['format'] != 'aftermind-recovery' ||
          manifest['version'] != 1 ||
          manifest['files'] is! Map) {
        throw const FormatException('Nepodporovaný formát zálohy.');
      }
      final expected = manifest['files'] as Map;
      if (expected.length != archive.length - 1 ||
          !expected.containsKey(databaseName)) {
        throw const FormatException('Seznam souborů zálohy není úplný.');
      }
      for (final entry in archive) {
        if (entry.name == _manifestName) continue;
        final record = expected[entry.name];
        if (record is! Map ||
            record['bytes'] != entry.size ||
            record['sha256'] is! String) {
          throw const FormatException('Soubor nesouhlasí se seznamem zálohy.');
        }
        final file = File(p.join(stage.path, p.joinAll(entry.name.split('/'))));
        await file.parent.create(recursive: true);
        await _writeEntry(entry, file);
        if (await file.length() != record['bytes'] ||
            await _hash(file) != record['sha256']) {
          throw const FormatException('Kontrolní součet zálohy nesouhlasí.');
        }
      }
      await _verifyDatabase(stage);
      await _requireAbsent(destination.path);
      await stage.rename(destination.path);
    } finally {
      await input?.close();
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  static Future<void> _writeEntry(ArchiveFile entry, File file) async {
    final output = _BoundedOutput(OutputFileStream(file.path), entry.size);
    try {
      entry.writeContent(output);
    } finally {
      await output.close();
    }
    if (await file.length() != entry.size) {
      throw const FormatException('Délka souboru zálohy nesouhlasí.');
    }
  }
}

/// Enforce the declared size while decompressing, not after filling the disk.
class _BoundedOutput extends OutputStream {
  _BoundedOutput(this._output, this._limit)
    : super(byteOrder: _output.byteOrder);
  final OutputFileStream _output;
  final int _limit;
  int _written = 0;
  @override
  int get length => _written;
  void _reserve(int count) {
    if (count < 0 || _written + count > _limit) {
      throw const FormatException('Soubor překročil deklarovanou velikost.');
    }
    _written += count;
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    _output.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _reserve(length ?? bytes.length);
    _output.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      final count = stream.length > 65536 ? 65536 : stream.length;
      writeBytes(stream.readBytes(count).toUint8List());
    }
  }

  @override
  void flush() => _output.flush();
  @override
  void clear() {
    _written = 0;
    _output.clear();
  }

  @override
  Future<void> close() => _output.close();
  @override
  Uint8List subset(int start, [int? end]) => _output.subset(start, end);
}
