import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/recording_controller.dart';
import '../../core/formatting.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/menu_row.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/meetings_dao.dart';
import '../../data/db/daos/subjects_dao.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../subjects/subject_actions.dart';
import '../subjects/subject_detail_screen.dart';
import '../subjects/subjects_providers.dart';
import '../subjects/timetable.dart';
import '../subjects/widgets/lesson_sheet.dart';
import '../subjects/widgets/subject_badge.dart';
import 'meeting_actions.dart';
import 'meetings_list_providers.dart';
import 'widgets/onboarding_card.dart';
import '../../core/pending_deletions.dart';

/// Home screen: a big start card, then every recorded meeting, newest first.
class MeetingsListScreen extends ConsumerStatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  ConsumerState<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends ConsumerState<MeetingsListScreen> {
  /// Meeting ids whose entrance has already played — see the same field on
  /// `MeetingDetailScreen` for why the bookkeeping lives here and not inside
  /// [Entrance].
  final _seen = <int>{};

  /// A second tap on the start card while the first is still opening the
  /// microphone would otherwise push the meeting screen twice.
  bool _starting = false;

  /// Set once the checklist has been seen unfinished, so finishing it during
  /// this visit leaves a „Hotovo" card to close instead of it vanishing, while
  /// someone who set everything up long ago never sees it at all.
  bool _onboardingActive = false;

  Future<void> _startRecording() async {
    if (_starting) return;
    _starting = true;
    try {
      final setup = await showStartRecordingSheet(context, ref);
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
              .push(SubjectDetailScreen.route(id, initialTab: 2));
        } else {
          await Navigator.of(context).push(
            SubjectDetailScreen.route(subjects.first.subject.id, initialTab: 2),
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
    final isRecording = ref.watch(
      recordingControllerProvider.select((s) => s.isRecording),
    );
    final recordingError = ref.watch(
      recordingControllerProvider.select((s) => s.error),
    );
    final keyKnown = ref.watch(hasApiKeyProvider).valueOrNull;
    final hasKey = keyKnown ?? true;
    final onboarding = _onboarding(keyKnown);
    // The navigation bar floats over the list; its height arrives as padding.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Nahrávky'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Nastavení',
                onPressed: _openSettings,
              ),
            ],
          ),
          // Recording works without a key — the audio is kept and queued either
          // way — but nothing will ever be transcribed, so say so before the
          // user records an hour and wonders where the text is.
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
          if (recordingError != null)
            SliverToBoxAdapter(
              child: _Notice(
                icon: Icons.error_outline,
                title: 'Nahrávání skončilo chybou',
                message: recordingError,
                tone: ChipTone.alert,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.xs,
              ),
              child: _RecordHero(
                isRecording: isRecording,
                onStart: _startRecording,
                onOpen: _openRecording,
              ),
            ),
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

  Widget _buildList(List<MeetingSummary> list) {
    if (list.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.mic_none_outlined,
          title: 'Zatím žádné nahrávky',
          message:
              'Začni kartou nahoře. Přepis začne přibývat během pár '
              'vteřin.',
        ),
      );
    }

    final firstPaint = _seen.isEmpty;
    final entering = <int, int>{};
    for (final summary in list) {
      if (_seen.add(summary.meeting.id)) {
        entering[summary.meeting.id] = entering.length;
      }
    }

    // Day headers interleaved with the rows they cover, so this can stay one
    // flat lazy list rather than a column of nested ones.
    final rows = <Object>[];
    String? group;
    for (final summary in list) {
      final label = formatDateGroup(summary.meeting.createdAt);
      if (label != group) {
        rows.add(label);
        group = label;
      }
      rows.add(summary);
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      sliver: SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final row = rows[i];
          if (row is String) return _DayHeader(label: row, first: i == 0);

          final summary = row as MeetingSummary;
          final order = entering[summary.meeting.id];
          return Entrance(
            enabled: order != null,
            delay: firstPaint && order != null
                ? AppMotion.staggerDelay(order)
                : Duration.zero,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Pressable(child: _MeetingCard(summary: summary)),
            ),
          );
        },
      ),
    );
  }
}

/// The start button as the first thing on the screen: a large card that says
/// what is on right now according to the timetable, with a breathing record
/// button. While a recording runs it turns red and opens that recording.
class _RecordHero extends ConsumerStatefulWidget {
  const _RecordHero({
    required this.isRecording,
    required this.onStart,
    required this.onOpen,
  });

  final bool isRecording;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  @override
  ConsumerState<_RecordHero> createState() => _RecordHeroState();
}

class _RecordHeroState extends ConsumerState<_RecordHero>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The hint depends on the clock. No periodic timer (it would outlive a
  /// widget test); coming back to the app is when it most needs to be fresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  String? _hint(List<TimetableSlot> slots, List<SubjectSummary> subjects) {
    final hint = todaySlotHint(slots, DateTime.now());
    if (hint == null) return null;
    String? name;
    for (final s in subjects) {
      if (s.subject.id == hint.slot.subjectId) name = s.subject.name;
    }
    if (name == null) return null;
    return hint.running
        ? 'Teď: $name do ${formatMinuteOfDay(hint.slot.endMinute)}'
        : 'Další: $name v ${formatMinuteOfDay(hint.slot.startMinute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recording = widget.isRecording;
    final hint = recording
        ? null
        : _hint(
            ref.watch(allSlotsProvider).valueOrNull ?? const [],
            ref.watch(subjectsProvider).valueOrNull ?? const [],
          );

    final (start, end, fg) = recording
        ? (
            scheme.errorContainer,
            Color.alphaBlend(
              scheme.error.withValues(alpha: 0.12),
              scheme.errorContainer,
            ),
            scheme.onErrorContainer,
          )
        : (
            scheme.primaryContainer,
            Color.alphaBlend(
              scheme.tertiaryContainer.withValues(alpha: 0.6),
              scheme.primaryContainer,
            ),
            scheme.onPrimaryContainer,
          );

    return Pressable(
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Gap.sheetRadius),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [start, end],
              ),
            ),
            child: InkWell(
              onTap: recording ? widget.onOpen : widget.onStart,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.xl,
                  Gap.lg,
                  Gap.md,
                  Gap.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hint != null) ...[
                            _HintPill(label: hint, color: fg),
                            const SizedBox(height: Gap.sm),
                          ],
                          Text(
                            recording ? 'Nahrává se' : 'Nahrát hodinu',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(
                            recording
                                ? 'Klepni a vrať se k přepisu.'
                                : 'Přepis začne přibývat během pár vteřin.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: fg.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    _BreathingButton(recording: recording),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Gap.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: color),
          const SizedBox(width: Gap.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The round record button with a soft halo that slowly swells and settles.
/// Under reduced motion the halo is drawn once, at rest.
class _BreathingButton extends StatefulWidget {
  const _BreathingButton({required this.recording});

  final bool recording;

  @override
  State<_BreathingButton> createState() => _BreathingButtonState();
}

class _BreathingButtonState extends State<_BreathingButton>
    with SingleTickerProviderStateMixin {
  static const _size = 60.0;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = reducedMotion(context);

    Widget halo(double t) => Container(
      width: _size * (1.16 + 0.16 * t),
      height: _size * (1.16 + 0.16 * t),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.error.withValues(alpha: 0.18 - 0.1 * t),
      ),
    );

    return SizedBox.square(
      dimension: _size * 1.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (reduced)
            halo(0)
          else
            AnimatedBuilder(
              animation: _breath,
              builder: (_, _) =>
                  halo(Curves.easeInOut.transform(_breath.value)),
            ),
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: scheme.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.error.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              widget.recording ? Icons.graphic_eq : Icons.mic,
              color: scheme.onError,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

/// `Dnes`, `Včera`, then the date. The stored title already carries the full
/// date, but a heading is what lets someone find last Thursday by scrolling
/// rather than by reading every row.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.first});

  final String label;

  /// The topmost header sits right under the start card and needs less air
  /// above it than one that follows a meeting.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        top: first ? Gap.lg : Gap.lg + Gap.xs,
        bottom: Gap.sm,
        left: Gap.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _CardAction { rename, delete }

class _MeetingCard extends ConsumerWidget {
  const _MeetingCard({required this.summary});

  final MeetingSummary summary;

  Meeting get meeting => summary.meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLive = ref.watch(
      recordingControllerProvider.select(
        (s) => s.isRecording && s.meetingId == meeting.id,
      ),
    );
    final chips = _chips(isLive);
    final named = !isDefaultMeetingTitle(meeting.title);
    final subject = summary.subject;
    final accent = subject == null
        ? null
        : subjectColor(context, subject.colorIndex);

    return Card(
      child: InkWell(
        onTap: () =>
            Navigator.of(context).push(MeetingDetailScreen.route(meeting.id)),
        child: Stack(
          children: [
            if (accent != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: accent),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.md,
                Gap.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Leading(isLive: isLive, accent: accent),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The time, not a generated `Schůzka 08.09. 09:50`
                        // title — under a `Dnes` heading two thirds of that
                        // repeats what the heading just said. A title the user
                        // gave is shown, since that is how they will look for
                        // the meeting.
                        Text(
                          named
                              ? meeting.title
                              : formatTimeOfDay(meeting.createdAt),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        const SizedBox(height: Gap.xs),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 13,
                              color: scheme.outline,
                            ),
                            const SizedBox(width: Gap.xs),
                            Text(
                              named
                                  ? '${formatTimeOfDay(meeting.createdAt)} · '
                                        '${formatDurationLabel(summary.duration)}'
                                  : formatDurationLabel(summary.duration),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                          ],
                        ),
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: Gap.sm),
                          Wrap(
                            spacing: Gap.xs + 2,
                            runSpacing: Gap.xs + 2,
                            children: chips,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Pulled up and in so the button's touch target does not
                  // make the card taller than its text.
                  Transform.translate(
                    offset: const Offset(Gap.sm, -Gap.sm),
                    child: PopupMenuButton<_CardAction>(
                      icon: Icon(Icons.more_vert, color: scheme.outline),
                      tooltip: 'Další akce',
                      onSelected: (action) => switch (action) {
                        _CardAction.rename => renameMeetingFlow(
                          context,
                          ref,
                          meeting,
                        ),
                        _CardAction.delete => confirmAndDeleteMeeting(
                          context,
                          ref,
                          meetingId: meeting.id,
                        ),
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: _CardAction.rename,
                          child: MenuRow(
                            icon: Icons.drive_file_rename_outline,
                            label: 'Přejmenovat',
                          ),
                        ),
                        PopupMenuItem(
                          value: _CardAction.delete,
                          enabled: !isLive,
                          child: MenuRow(
                            icon: Icons.delete_outline,
                            label: 'Smazat',
                            destructive: true,
                            enabled: !isLive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Only what is worth saying. A finished meeting whose transcript is complete
  /// gets no chips at all, which is what makes the ones that do stand out.
  List<Widget> _chips(bool isLive) {
    return [
      if (summary.subject != null) SubjectBadge(subject: summary.subject!),
      if (isLive)
        const StatusChip(
          icon: Icons.fiber_manual_record,
          label: 'Nahrává se',
          tone: ChipTone.alert,
        ),
      if (summary.importantCount > 0)
        StatusChip(
          icon: Icons.star_rounded,
          label: '${summary.importantCount}',
          tone: ChipTone.progress,
        ),
      if (summary.failedCount > 0)
        StatusChip(
          icon: Icons.error_outline,
          label: '${summary.failedCount}× chyba',
          tone: ChipTone.alert,
        ),
      if (summary.outstandingCount > 0)
        StatusChip(
          icon: Icons.sync,
          label: 'Přepis ${summary.transcribedCount}/${summary.segmentCount}',
          tone: ChipTone.progress,
        ),
      if (summary.weakAudio)
        const StatusChip(
          icon: Icons.graphic_eq,
          label: 'Slabý zvuk',
          tone: ChipTone.alert,
        ),
      if (summary.segmentCount == 0)
        const StatusChip(icon: Icons.mic_off_outlined, label: 'Bez záznamu'),
      if (meeting.interrupted)
        const StatusChip(icon: Icons.power_settings_new, label: 'Přerušeno'),
    ];
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.isLive, this.accent});

  final bool isLive;

  /// The lesson's subject colour; plain grey for an ordinary meeting.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accent;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isLive
            ? scheme.errorContainer
            : tint?.withValues(alpha: 0.16) ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.md),
      ),
      child: Icon(
        isLive
            ? Icons.fiber_manual_record
            : tint != null
            ? Icons.school_outlined
            : Icons.description_outlined,
        size: 19,
        color: isLive ? scheme.error : tint ?? scheme.onSurfaceVariant,
      ),
    );
  }
}

/// A rounded note above the list: something is wrong, or something is missing
/// that the user will want to fix before recording.
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
        : (scheme.secondaryContainer, scheme.onSecondaryContainer);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xs),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(Gap.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: Gap.xs),
                        Text(
                          message!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 20, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
