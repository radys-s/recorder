import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where recorded chunks live, relative to the app documents directory.
const String kRecordingsDirName = 'recordings';

/// Turns an absolute path inside the documents directory into the form that
/// goes in the database — `recordings/meeting_12/chunk_0003.wav`.
///
/// The absolute container path is not stable on iOS. It is
/// `/var/mobile/Containers/Data/Application/<UUID>/Documents/…`, and Apple
/// makes no promise about the UUID surviving a reinstall — which under
/// SideStore happens every seven days, because that is how often a free
/// developer signature has to be refreshed. A queue row written before the
/// refresh would then name a file that no longer exists, and an upload that
/// only ever needed retrying would start throwing `FileSystemException`
/// instead. Storing the part of the path the app actually owns and re-joining
/// it against a freshly fetched documents directory at read time removes the
/// problem rather than papering over it.
///
/// Anything outside [docsPath] is returned unchanged: there is nothing to be
/// relative *to*, and a path the app did not place there is not ours to
/// rewrite.
String toStoredPath(String docsPath, String absolutePath) {
  final relative = p.relative(absolutePath, from: docsPath);
  // `p.relative` climbs out with `..` rather than failing, so that is the
  // signal that the file is somewhere else entirely.
  if (relative.startsWith('..')) return absolutePath;
  // Forward slashes regardless of host, so a row written on one platform
  // reads on the other. Both platforms accept them.
  return p.posix.joinAll(p.split(relative));
}

/// The inverse, for a path that came back out of the database.
///
/// Backwards compatible on purpose: rows written before this existed hold
/// absolute paths, and on Android those keep working forever, so an absolute
/// stored path is used as-is and there is no migration to run.
Future<String> resolveStoredPath(String stored) async {
  if (p.isAbsolute(stored)) return stored;
  return p.join(await _documentsPath(), p.joinAll(p.posix.split(stored)));
}

/// The documents directory, asked for once per process.
///
/// The queue worker resolves a path per row, and every one of those is a
/// platform-channel round trip on the main isolate — the same isolate that
/// draws the transcript. The answer cannot change while the app is running,
/// so caching it is free. The future itself is cached rather than the string,
/// so two rows resolved at the same time still make one call.
Future<String>? _docsFuture;

Future<String> _documentsPath() async =>
    (_docsFuture ??= getApplicationDocumentsDirectory().then((d) => d.path));

/// Drops the cached documents directory. Tests only — nothing at runtime has
/// a reason to, since the path is fixed for the life of the process.
@visibleForTesting
void resetDocumentsPathCache() => _docsFuture = null;
