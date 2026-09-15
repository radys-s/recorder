import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'data/db/app_database.dart';
import 'features/meeting_detail/widgets/recording_indicator_banner.dart';
import 'features/home/home_shell.dart';

class RecorderApp extends ConsumerStatefulWidget {
  const RecorderApp({super.key});

  @override
  ConsumerState<RecorderApp> createState() => _RecorderAppState();
}

class _RecorderAppState extends ConsumerState<RecorderApp> {
  static const _tag = 'app';

  @override
  void initState() {
    super.initState();
    unawaited(_startup());
  }

  /// Runs once, before anything can be recording — which is what makes the
  /// orphan cleanup safe, since an open `endedAt` means "in progress" at any
  /// other time.
  ///
  /// Every step is guarded on its own. They used to run as one chain, so a
  /// failure in housekeeping — a locked database row, a migration hiccup —
  /// skipped starting the queue worker, and every chunk recorded afterwards
  /// sat untranscribed with nothing on screen saying why.
  Future<void> _startup() async {
    final db = ref.read(appDatabaseProvider);

    // Closing comes first: deleteEmptyMeetings only considers closed rows, so
    // running it the other way round would let an interrupted meeting that
    // never produced a chunk sit in the list for exactly one more launch.
    await _step('close orphaned meetings', () async {
      final orphans = await db.meetingsDao.closeOrphanedMeetings();
      if (orphans.isNotEmpty) {
        AppLog.d(_tag, 'closed interrupted meeting(s): $orphans');
      }
    });

    await _step('delete empty meetings', () async {
      final emptied = await db.meetingsDao.deleteEmptyMeetings();
      if (emptied > 0) {
        AppLog.d(_tag, 'removed $emptied meeting(s) that never produced audio');
      }
    });

    // Deleting a meeting does not stop work already in flight for it: a chunk
    // mid-upload can still land an answer card for a meeting that is gone.
    // Nothing shows such rows, so this only keeps the database honest.
    await _step('delete orphan rows', () async {
      final removed = await db.meetingsDao.deleteOrphanRows();
      if (removed > 0) {
        AppLog.d(_tag, 'removed $removed row(s) of deleted meetings');
      }
    });

    // A generation dies with the process, so a row still claiming to be
    // generating is a leftover, not work in progress — left alone it would sit
    // under a progress bar forever.
    await _step('fail interrupted generations', () async {
      final stuck = await db.meetingNotesDao.failInterruptedGenerations();
      if (stuck > 0) {
        AppLog.d(_tag, 'reopened $stuck note generation(s) killed mid-flight');
      }
    });

    // Same reasoning for a chat reply: a pending bubble would say
    // „Přemýšlím…" forever.
    await _step('fail interrupted chat replies', () async {
      final stuck = await db.chatMessagesDao.failInterruptedReplies();
      if (stuck > 0) {
        AppLog.d(_tag, 'failed $stuck chat reply(ies) killed mid-flight');
      }
    });

    // Started here rather than lazily on first use: starting the worker is
    // what picks up chunks a previous run left unsent, and that has to happen
    // even if the user never opens the screen those chunks belong to.
    await _step('start queue worker', () => ref.read(queueWorkerProvider).start());
  }

  Future<void> _step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      AppLog.e(_tag, 'startup step "$name" failed', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recorder',
      navigatorKey: appNavigatorKey,
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      // Follows the device. The Android launch window already has a night
      // variant, so a light-only app flashed dark-then-light on every
      // night-mode cold start.
      themeMode: ThemeMode.system,
      // Czech only: the app has no English audience, and pinning the locale
      // keeps Material's own strings from following the device.
      locale: const Locale('cs'),
      supportedLocales: const [Locale('cs')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Above the Navigator rather than inside a route: an indicator that
      // vanishes the moment the user opens Settings is not an indicator.
      builder: (_, child) => RecordingIndicatorBanner(child: child!),
      home: const HomeShell(),
    );
  }
}
