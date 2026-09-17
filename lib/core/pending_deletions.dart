import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logging.dart';

enum DeletionKind { meeting, note, card }

typedef DeletionKey = ({DeletionKind kind, int id});

/// How long „Vrátit" stays on screen. A provider so tests can shorten it.
final deletionUndoWindowProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Deletes that have been asked for but not carried out yet.
///
/// Scheduling hides the item at once — every list filters out what is in
/// [state] — and the real delete runs when the window ends. Undo just drops
/// it from the set. The id leaves the set only after the delete has finished,
/// so a list never shows the row again for the frame between the two.
///
/// If the app is killed inside the window the item simply stays, which is the
/// safe direction; going to the background commits everything pending.
class PendingDeletions extends Notifier<Set<DeletionKey>> {
  static const _tag = 'deletions';

  final _timers = <DeletionKey, Timer>{};
  final _commits = <DeletionKey, Future<void> Function()>{};

  @override
  Set<DeletionKey> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
    });
    return const {};
  }

  bool isPending(DeletionKind kind, int id) =>
      state.contains((kind: kind, id: id));

  void schedule(DeletionKind kind, int id, Future<void> Function() commit) {
    final key = (kind: kind, id: id);
    if (_commits.containsKey(key)) return;
    _commits[key] = commit;
    _timers[key] = Timer(ref.read(deletionUndoWindowProvider), () {
      unawaited(_commit(key));
    });
    state = {...state, key};
  }

  /// True when the delete had not happened yet.
  bool undo(DeletionKind kind, int id) {
    final key = (kind: kind, id: id);
    _timers.remove(key)?.cancel();
    if (_commits.remove(key) == null) return false;
    state = {...state}..remove(key);
    return true;
  }

  Future<void> commitAll() async {
    for (final key in _commits.keys.toList()) {
      await _commit(key);
    }
  }

  Future<void> _commit(DeletionKey key) async {
    _timers.remove(key)?.cancel();
    final commit = _commits.remove(key);
    if (commit == null) return;
    try {
      await commit();
    } catch (e, st) {
      AppLog.e(_tag, '$key: delete failed', e, st);
    } finally {
      state = {...state}..remove(key);
    }
  }
}

final pendingDeletionsProvider =
    NotifierProvider<PendingDeletions, Set<DeletionKey>>(PendingDeletions.new);

/// Ids of [kind] waiting to be deleted, for a list to leave out.
final pendingIdsProvider = Provider.family<Set<int>, DeletionKind>((ref, kind) {
  return {
    for (final key in ref.watch(pendingDeletionsProvider))
      if (key.kind == kind) key.id,
  };
});

/// Schedules a delete and shows „[message] · Vrátit" for the undo window.
///
/// [messenger] is captured by the caller before any route is popped, since
/// the snackbar has to outlive the screen that asked for it.
void deleteWithUndo({
  required ScaffoldMessengerState messenger,
  required WidgetRef ref,
  required DeletionKind kind,
  required int id,
  required String message,
  required Future<void> Function() commit,
}) {
  final notifier = ref.read(pendingDeletionsProvider.notifier);
  notifier.schedule(kind, id, commit);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: ref.read(deletionUndoWindowProvider),
        action: SnackBarAction(
          label: 'Vrátit',
          onPressed: () => notifier.undo(kind, id),
        ),
      ),
    );
}
