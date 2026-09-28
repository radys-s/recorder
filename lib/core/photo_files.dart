import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'paths.dart';

/// Where photos live, relative to the documents directory — the same rule as
/// recordings, for the same SideStore reason (see `toStoredPath`).
const String kPhotosDirName = 'photos';
const String kCardPhotosDirName = 'cards';

String meetingPhotosDir(String docsPath, int meetingId) =>
    p.join(docsPath, kPhotosDirName, 'meeting_$meetingId');

String cardPhotosDir(String docsPath, int cardId) =>
    p.join(docsPath, kCardPhotosDirName, 'card_$cardId');

/// The MIME type Gemini needs, from a file name. The picker hands back JPEG
/// for anything it re-encodes; the rest is what a gallery can still produce.
String photoMimeType(String path) => switch (p.extension(path).toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      '.heif' => 'image/heif',
      _ => 'image/jpeg',
    };

/// Writes photo bytes into [dir] under a fresh name and returns the stored
/// (relative) path.
Future<String> savePhoto({
  required String docsPath,
  required String dir,
  required Uint8List bytes,
  String extension = '.jpg',
  DateTime? now,
}) async {
  final directory = Directory(dir);
  await directory.create(recursive: true);
  final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
  var file = File(p.join(dir, 'photo_$stamp$extension'));
  for (var n = 1; await file.exists(); n++) {
    file = File(p.join(dir, 'photo_${stamp}_$n$extension'));
  }
  await file.writeAsBytes(bytes, flush: true);
  return toStoredPath(docsPath, file.path);
}

/// Copies already stored photos into [dir] (a board photo becoming a card's
/// page) and returns the new stored paths. Missing sources are skipped: the
/// card is worth more than the picture.
Future<List<String>> copyPhotos({
  required String docsPath,
  required String dir,
  required List<String> storedPaths,
}) async {
  final copied = <String>[];
  for (final stored in storedPaths) {
    final source = File(p.isAbsolute(stored)
        ? stored
        : p.join(docsPath, p.joinAll(p.posix.split(stored))));
    if (!await source.exists()) continue;
    copied.add(await savePhoto(
      docsPath: docsPath,
      dir: dir,
      bytes: await source.readAsBytes(),
      extension: p.extension(source.path).isEmpty
          ? '.jpg'
          : p.extension(source.path),
    ));
  }
  return copied;
}

/// Deletes a directory if it is there. Throws what the file system throws;
/// callers decide whether that matters.
Future<void> removeDirectory(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) await dir.delete(recursive: true);
}

/// Deletes stored photos one by one. A file already gone is not an error.
Future<void> removePhotoFiles(List<String> storedPaths) async {
  for (final stored in storedPaths) {
    final file = File(await resolveStoredPath(stored));
    if (await file.exists()) await file.delete();
  }
}
