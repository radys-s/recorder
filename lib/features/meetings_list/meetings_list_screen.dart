import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/recording_controller.dart';
import '../../core/formatting.dart';
import '../../core/motion.dart';
import '../../core/pending_deletions.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/inset_group.dart';
import '../../core/widgets/menu_row.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/db/daos/meetings_dao.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../notes_library/notes_library_providers.dart';
import '../notes_library/saved_note_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../subjects/subject_actions.dart';
import '../subjects/subject_detail_screen.dart';
import '../subjects/subjects_providers.dart';
import '../subjects/widgets/lesson_sheet.dart';
import 'meeting_actions.dart';
import 'meetings_list_providers.dart';
import 'widgets/dashboard_stage.dart';
import 'widgets/onboarding_card.dart';

/// Home screen: a dark stage with the record control (and, while a lesson
/// runs, the recording itself), then the latest notes and every lesson as
/// iOS-style inset groups, newest first.
class MeetingsListScreen extends ConsumerStatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  ConsumerState<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends ConsumerState<MeetingsListScreen> {
  // Show the persistent recording strip before the dashboard's own status
  // scrolls out of sight. The generous overlap is intentional: seeing both
  // briefly is safer than having no recording indicator at all.
  static const _showStripAfter = 120.0;
  static const _hideStripBefore = 40.0;
  late final ScrollController _scrollController = ScrollController()
    ..addListener(_syncStageInView);

  void _syncStageInView() {
    final notifier = ref.read(dashboardStageInViewProvider.notifier);
    // The strip changes the viewport height. Separate thresholds stop that
    // layout change from toggling the strip back and forth near one boundary.
    final inView = notifier.state
        ? _scrollController.offset < _showStripAfter
        : _scrollController.offset < _hideStripBefore;
    if (notifier.state != inView) notifier.state = inView;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Day groups whose entrance has already played. Rows of a group arrive
  /// together, so the group — not the row — is what enters.
  final _seen = <String>{};

  /// A second tap on the record disc while the first is still opening the
  /// microphone would otherwise push the meeting screen twice.
  bool _starting = false;

  /// Set once the checklist has been seen unfinished, so finishing it during
  /// this visit leaves a „Hotovo" card to close instead of it vanishing, while
  /// someone who set everything up long ago never sees it at all.
  bool _onboardingActive = false;

  Future<void> _startRecording({int? subjectId}) async {
    if (_starting) return;
    _starting = true;
    try {
      final setup = await showStartRecordingSheet(
        context,
        ref,
        preselectSubjectId: subjectId,
      );
      if (setup == null || !mounted) return;
      HapticFeedback.mediumImpact();
      await ref
          .read(recordingControllerProvider.notifier)
          .start(
            subjectId: setup.subjectId,
            cardIds: setup.cardIds,
            rules: setup.rules,
          );

      final meetingId = ref.read(recordingControllerProvider).meetingId;
      if (meetingId == null || !mounted) return;
      await Navigator.of(context).push(MeetingDetailScreen.route(meetingId));
    } finally {
      _starting = false;
    }
  }

  void _openRecording() {
    final id = ref.read(recordingControllerProvider).meetingId;
    if (id != null) Navigator.of(context).push(MeetingDetailScreen.route(id));
  }

  Future<void> _resumeRecording() async {
    await ref.read(recordingControllerProvider.notifier).resume();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    if (!mounted) return;
    ref
      ..invalidate(hasApiKeyProvider)
      ..invalidate(hasGeminiKeyProvider);
  }

  Future<void> _onboardingStep(OnboardingStep step) async {
    switch (step) {
      case OnboardingStep.groqKey:
      case OnboardingStep.geminiKey:
      case OnboardingStep.study:
        await _openSettings();
      case OnboardingStep.subject:
        await createSubjectFlow(context, ref);
      case OnboardingStep.timetable:
        final subjects = ref.read(subjectsProvider).valueOrNull ?? const [];
        if (subjects.isEmpty) {
          final id = await createSubjectFlow(context, ref);
          if (id == null || !mounted) return;
          await Navigator.of(context)
              .push(SubjectDetailScreen.route(id, initialTab: 3));
        } else {
          await Navigator.of(context).push(
            SubjectDetailScreen.route(subjects.first.subject.id, initialTab: 3),
          );
        }
    }
  }

  /// The checklist, or null when it should not show.
  List<OnboardingItem>? _onboarding(bool? hasKey) {
    final prefs = ref.watch(preferencesProvider).valueOrNull;
    final dismissed = prefs?.onboardingDismissed;
    final hasGemini = ref.watch(hasGeminiKeyProvider).valueOrNull;
    final subjects = ref.watch(subjectsProvider).valueOrNull;
    final slots = ref.watch(allSlotsProvider).valueOrNull;
    if (dismissed != false ||
        hasKey == null ||
        hasGemini == null ||
        subjects == null ||
        slots == null) {
      return null;
    }
    final steps = onboardingSteps(
      hasGroqKey: hasKey,
      hasGeminiKey: hasGemini,
      hasSubject: subjects.isNotEmpty,
      hasStudyProfile: prefs?.studyYear != null || prefs?.schoolName != null,
      hasTimetable: slots.isNotEmpty,
    );
    if (!onboardingRequiredDone(steps)) _onboardingActive = true;
    return _onboardingActive ? steps : null;
  }

  @override
  Widget build(BuildContext context) {
    // A tapped lesson reminder opens the start sheet with its own subject
    // already chosen. It is consumed here, so it cannot fire twice.
    ref.listen(pendingReminderSubjectProvider, (_, subjectId) {
      if (subjectId == null) return;
      ref.read(pendingReminderSubjectProvider.notifier).state = null;
      unawaited(_startRecording(subjectId: subjectId));
    });

    final hidden = ref.watch(pendingIdsProvider(DeletionKind.meeting));
    final summaries = ref
        .watch(meetingSummariesProvider)
        .whenData(
          (all) => hidden.isEmpty
              ? all
              : [
                  for (final s in all)
                    if (!hidden.contains(s.meeting.id)) s,
                ],
        );
    final liveMeetingId = ref.watch(
      recordingControllerProvider.select((s) => s.meetingId),
    );
    final recordingError = ref.watch(
      recordingControllerProvider.select((s) => s.error),
    );
    final keyKnown = ref.watch(hasApiKeyProvider).valueOrNull;
    final hasKey = keyKnown ?? true;
    final onboarding = _onboarding(keyKnown);
    // The shell's floating tab bar arrives as bottom padding, so this clears
    // both the bar and the home indicator.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final latest = _latestNotes(summaries.valueOrNull);

    String? liveSubject;
    for (final s in summaries.valueOrNull ?? const <MeetingSummary>[]) {
      if (s.meeting.id == liveMeetingId) liveSubject = s.subject?.name;
    }

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: DashboardStage(
              date: formatDashboardDate(DateTime.now()),
              liveSubjectName: liveSubject,
              onStart: _startRecording,
              onOpen: _openRecording,
              onResume: _resumeRecording,
              onSearch: () => Navigator.of(context).push(SearchScreen.route()),
              onSettings: _openSettings,
            ),
          ),
          if (recordingError != null)
            SliverToBoxAdapter(
              child: _Notice(
                icon: Icons.error_outline,
                title: 'Nahrávání skončilo chybou',
                message: recordingError,
                tone: ChipTone.alert,
              ),
            ),
          // Recording works without a key — the audio is kept and queued either
          // way — but nothing will ever be transcribed, so say so right under
          // the stage, before the user records an hour and wonders where the
          // text is.
          if (onboarding != null)
            SliverToBoxAdapter(
              child: OnboardingCard(
                steps: onboarding,
                onStep: _onboardingStep,
                onClose: () => ref
                    .read(preferencesDaoProvider)
                    .setOnboardingDismissed(true),
              ),
            ),
          // The checklist already says the key is missing.
          if (!hasKey && onboarding == null)
            SliverToBoxAdapter(
              child: _Notice(
                icon: Icons.key_off,
                title: 'Chybí Groq API klíč',
                message: 'Nahrávat můžeš, ale přepis se nespustí.',
                onTap: _openSettings,
              ),
            ),
          if (latest != null)
            SliverToBoxAdapter(
              child: InsetGroup(label: 'Poslední výpisky', children: [latest]),
            ),
          AsyncSliver(
            value: summaries,
            message: 'Seznam schůzek se nepodařilo načíst.',
            onRetry: () => ref.invalidate(meetingSummariesProvider),
            builder: _buildList,
          ),
          SliverPadding(padding: EdgeInsets.only(bottom: Gap.xl + bottomInset)),
        ],
      ),
    );
  }

  /// The newest AI notes as a prose row, else the newest saved note.
  Widget? _latestNotes(List<MeetingSummary>? summaries) {
    final recent = ref.watch(latestLessonNotesProvider).valueOrNull;
    // [summaries] already hides meetings waiting out their undo window, so
    // the first notes whose meeting is listed are the newest visible ones.
    final byId = {
      for (final s in summaries ?? const <MeetingSummary>[]) s.meeting.id: s,
    };
    for (final notes in recent ?? const []) {
      final s = byId[notes.meetingId];
      if (s != null) {
        final subject = s.subject;
        final named = !isDefaultMeetingTitle(s.meeting.title);
        return ListRow(
          leading: SubjectDot(
            color: subject == null
                ? Theme.of(context).colorScheme.outline
                : subjectColor(context, subject.colorIndex),
          ),
          title: named ? s.meeting.title : (subject?.name ?? 'Hodina'),
          excerpt: notePreview(notes.content ?? ''),
          subtitle: [
            if (named) ?subject?.name,
            formatDateGroup(s.meeting.createdAt).toLowerCase(),
          ].join(' · '),
          onTap: () =>
              Navigator.of(context)
                  .push(MeetingDetailScreen.route(s.meeting.id)),
        );
      }
    }
    final saved = ref.watch(savedNotesProvider).valueOrNull;
    if (saved == null || saved.isEmpty) return null;
    // The library hides a note as soon as delete-with-undo is scheduled; the
    // dashboard must not keep linking to that still-present database row.
    final visible = filterSavedNotes(
      saved,
      hiddenIds: ref.watch(pendingIdsProvider(DeletionKind.note)),
    );
    if (visible.isEmpty) return null;
    final note = visible.first;
    return ListRow(
      leading: Icon(
        Icons.bookmark_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: note.title,
      excerpt: notePreview(note.content),
      subtitle:
          'Uložená poznámka · ${formatDateGroup(note.updatedAt).toLowerCase()}',
      onTap: () => Navigator.of(context).push(SavedNoteScreen.route(note.id)),
    );
  }

  Widget _buildList(List<MeetingSummary> list) {
    if (list.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.mic_none_outlined,
          title: 'Zatím žádné nahrávky',
          message:
              'Klepni na tlačítko nahrávání nahoře. Přepis začne přibývat '
              'během pár vteřin.',
        ),
      );
    }

    // One inset group per day.
    final groups = <(String, List<MeetingSummary>)>[];
    for (final summary in list) {
      final label = formatDateGroup(summary.meeting.createdAt);
      if (groups.isEmpty || groups.last.$1 != label) {
        groups.add((label, [summary]));
      } else {
        groups.last.$2.add(summary);
      }
    }

    final firstPaint = _seen.isEmpty;
    final entering = <String, int>{};
    for (final (label, _) in groups) {
      if (_seen.add(label)) entering[label] = entering.length;
    }

    return SliverList.builder(
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final (label, rows) = groups[i];
        final order = entering[label];
        return Entrance(
          enabled: order != null,
          delay: firstPaint && order != null
              ? AppMotion.staggerDelay(order)
              : Duration.zero,
          child: InsetGroup(
            label: label,
            children: [for (final s in rows) _MeetingRow(summary: s)],
          ),
        );
      },
    );
  }
}

/// `sobota 26. září`, spelled out here so the header does not depend on
/// intl's locale data having been loaded.
String formatDashboardDate(DateTime today) {
  const days = [
    'pondělí',
    'úterý',
    'středa',
    'čtvrtek',
    'pátek',
    'sobota',
    'neděle',
  ];
  const months = [
    'ledna',
    'února',
    'března',
    'dubna',
    'května',
    'června',
    'července',
    'srpna',
    'září',
    'října',
    'listopadu',
    'prosince',
  ];
  return '${days[today.weekday - 1]} ${today.day}. ${months[today.month - 1]}';
}

enum _RowAction { open, rename, delete }

/// One lesson: a subject dot, what it was, when and how long, and only the
/// states worth knowing. Rename and delete live behind a long press.
class _MeetingRow extends ConsumerWidget {
  const _MeetingRow({required this.summary});

  final MeetingSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meeting = summary.meeting;
    final isLive = ref.watch(
      recordingControllerProvider.select(
        (s) => s.isRecording && s.meetingId == meeting.id,
      ),
    );
    final subject = summary.subject;
    final named = !isDefaultMeetingTitle(meeting.title);
    final title = named ? meeting.title : (subject?.name ?? 'Schůzka');
    final subtitle = [
      if (named && subject != null) subject.name,
      formatTimeOfDay(meeting.createdAt),
      if (summary.segmentCount > 0) formatDurationLabel(summary.duration),
    ].join(' · ');
    final (status, alert) = _status(isLive);

    void open() =>
        Navigator.of(context).push(MeetingDetailScreen.route(meeting.id));

    return Semantics(
      hint: 'Podržením přejmenuješ nebo smažeš.',
      child: ListRow(
        leading: isLive
            ? const SubjectDot(color: AftermindPalette.record)
            : SubjectDot(
                color: subject == null
                    ? scheme.outline.withValues(alpha: 0.6)
                    : subjectColor(context, subject.colorIndex),
              ),
        title: title,
        subtitle: subtitle,
        status: status,
        statusColor: alert ? scheme.error : null,
        trailing: summary.importantCount > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 2),
                  Text(
                    '${summary.importantCount}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              )
            : null,
        onTap: open,
        onLongPress: () => _showActions(context, ref, isLive, open),
      ),
    );
  }

  /// Only what is worth saying; an ordinary finished lesson says nothing.
  (String?, bool) _status(bool isLive) {
    final alerts = [
      if (isLive) 'Nahrává se',
      if (summary.failedCount > 0) '${summary.failedCount}× chyba',
      if (summary.weakAudio) 'Slabý zvuk',
    ];
    final notes = [
      if (summary.outstandingCount > 0)
        'Přepis ${summary.transcribedCount}/${summary.segmentCount}',
      if (summary.segmentCount == 0 && !isLive) 'Bez záznamu',
      if (summary.meeting.interrupted) 'Přerušeno',
    ];
    final all = [...alerts, ...notes];
    if (all.isEmpty) return (null, false);
    return (all.join(' · '), alerts.isNotEmpty);
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    bool isLive,
    VoidCallback open,
  ) async {
    HapticFeedback.selectionClick();
    final meeting = summary.meeting;
    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Otevřít'),
              onTap: () => Navigator.of(sheetContext).pop(_RowAction.open),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Přejmenovat'),
              onTap: () => Navigator.of(sheetContext).pop(_RowAction.rename),
            ),
            ListTile(
              enabled: !isLive,
              title: MenuRow(
                icon: Icons.delete_outline,
                label: isLive ? 'Smazat (právě nahrává)' : 'Smazat',
                destructive: true,
                enabled: !isLive,
              ),
              onTap: () => Navigator.of(sheetContext).pop(_RowAction.delete),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _RowAction.open:
        open();
      case _RowAction.rename:
        await renameMeetingFlow(context, ref, meeting);
      case _RowAction.delete:
        await confirmAndDeleteMeeting(context, ref, meetingId: meeting.id);
    }
  }
}

/// A rounded note between the stage and the lists: something is wrong, or
/// something is missing that the user will want to fix before recording.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    this.message,
    this.tone = ChipTone.progress,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? message;
  final ChipTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = tone == ChipTone.alert
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : (scheme.surfaceContainerLow, scheme.onSurface);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xs),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(InsetGroup.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: tone == ChipTone.alert ? foreground : scheme.primary,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          message!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tone == ChipTone.alert
                                ? foreground
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
