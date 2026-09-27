import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging.dart';
import 'core/pending_deletions.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'data/db/app_database.dart';
import 'data/db/tables/preferences_table.dart';
import 'features/meeting_detail/widgets/recording_indicator_banner.dart';
import 'features/home/home_shell.dart';
import 'features/subjects/subjects_providers.dart';

class RecorderApp extends ConsumerStatefulWidget {
  const RecorderApp({super.key});

  @override
  ConsumerState<RecorderApp> createState() => _RecorderAppState();
}

class _RecorderAppState extends ConsumerState<RecorderApp>
    with WidgetsBindingObserver {
  static const _tag = 'app';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Going to the background commits every delete still waiting for „Vrátit",
  /// since iOS may never wake the app again to let the timers fire.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(ref.read(pendingDeletionsProvider.notifier).commitAll());
    }
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

    // Chunk WAVs are the only thing here that grows without bound — roughly
    // 1.9 MB a minute — so a lesson whose transcript is finished and whose
    // retention window has passed gives its audio back.
    await _step('clear old audio', () async {
      final cleared = await ref.read(audioCleanerProvider).sweep();
      if (cleared > 0) {
        AppLog.d(_tag, 'freed the audio of $cleared meeting(s)');
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
    await _step(
      'start queue worker',
      () => ref.read(queueWorkerProvider).start(),
    );
    // Not awaited: a pass can take minutes and must not hold up launch.
    await _step('resume refined transcripts', () async {
      unawaited(ref.read(refinedTranscriptServiceProvider).resume());
    });

    // Reminders are concrete notifications for the next fortnight rather than
    // a weekly repeat, so every launch plans the fortnight again. This is also
    // where a tap that started the app is picked up — on a cold start there is
    // no callback, only the launch details.
    await _step('schedule lesson reminders', () async {
      final subjectId = await ref.read(reminderSchedulerProvider).init();
      if (subjectId != null) {
        ref.read(pendingReminderSubjectProvider.notifier).state = subjectId;
      }
      await ref.read(lessonReminderServiceProvider).reschedule();
    });

    // Watches the subjects and mirrors them to Google Docs when the student
    // turned it on; a no-op until they sign in with Google.
    await _step(
      'sync google docs',
      () async => ref.read(driveSyncServiceProvider).start(),
    );
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
    // A timetable the student just edited has to change what the phone will
    // say tomorrow morning, not only after the next launch.
    ref.listen(allSlotsProvider, (previous, next) {
      if (previous?.value == null || next.value == null) return;
      unawaited(ref.read(lessonReminderServiceProvider).reschedule());
    });

    // The accent the student picked; gold until the preferences row loads.
    final accent =
        ref.watch(preferencesProvider).value?.accentPreset ?? AccentPreset.gold;

    return MaterialApp(
      title: 'Aftermind',
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver],
      theme: appTheme(Brightness.light, accent),
      darkTheme: appTheme(Brightness.dark, accent),
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
