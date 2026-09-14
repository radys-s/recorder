import 'package:flutter/material.dart';
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
import '../../core/widgets/status_chip.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/meetings_dao.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../settings/settings_screen.dart';
import 'meeting_actions.dart';
import 'meetings_list_providers.dart';

/// Home screen: every recorded meeting, newest first.
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

  /// A second tap on the FAB while the first is still opening the microphone
  /// would otherwise push the meeting screen twice.
  bool _starting = false;

  Future<void> _startRecording() async {
    if (_starting) return;
    _starting = true;
    try {
      await ref.read(recordingControllerProvider.notifier).start();

      final meetingId = ref.read(recordingControllerProvider).meetingId;
      if (meetingId == null || !mounted) return;
      await Navigator.of(context).push(MeetingDetailScreen.route(meetingId));
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(meetingSummariesProvider);
    final isRecording =
        ref.watch(recordingControllerProvider.select((s) => s.isRecording));
    final recordingError =
        ref.watch(recordingControllerProvider.select((s) => s.error));
    final hasKey = ref.watch(hasApiKeyProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schůzky'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: isRecording
          ? null
          : FloatingActionButton.extended(
              onPressed: _startRecording,
              icon: const Icon(Icons.mic),
              label: const Text('Nahrávat'),
            ),
      body: Column(
        children: [
          // Recording works without a key — the audio is kept and queued either
          // way — but nothing will ever be transcribed, so say so before the
          // user records an hour and wonders where the text is.
          if (!hasKey)
            _Notice(
              icon: Icons.key_off,
              title: 'Chybí Groq API klíč',
              message: 'Nahrávat můžeš, ale přepis se nespustí.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          if (recordingError != null)
            _Notice(
              icon: Icons.error_outline,
              title: 'Nahrávání skončilo chybou',
              message: recordingError,
              tone: ChipTone.alert,
            ),
          Expanded(
            child: AsyncView(
              value: summaries,
              message: 'Seznam schůzek se nepodařilo načíst.',
              onRetry: () => ref.invalidate(meetingSummariesProvider),
              builder: _buildList,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<MeetingSummary> list) {
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.mic_none_outlined,
        title: 'Zatím žádné schůzky',
        message: 'Začni tlačítkem Nahrávat dole. Přepis '
            'začne přibývat během pár vteřin.',
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          Gap.lg, Gap.xs, Gap.lg, Gap.fabClearance),
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
            child: _MeetingCard(summary: summary),
          ),
        );
      },
    );
  }
}

/// `Dnes`, `Včera`, then the date. The stored title already carries the full
/// date, but a heading is what lets someone find last Thursday by scrolling
/// rather than by reading every row.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.first});

  final String label;

  /// The topmost header sits right under the app bar and needs less air above
  /// it than one that follows a card.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: first ? Gap.sm : Gap.lg, bottom: Gap.sm),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
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

    return Card(
      child: InkWell(
        onTap: () =>
            Navigator.of(context).push(MeetingDetailScreen.route(meeting.id)),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Leading(isLive: isLive),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The time, not a generated `Schůzka 08.09. 09:50` title —
                    // under a `Dnes` heading two thirds of that repeats what
                    // the heading just said. A title the user gave is shown,
                    // since that is how they will look for the meeting.
                    Text(
                      named ? meeting.title : formatTimeOfDay(meeting.createdAt),
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
              // Pulled up and in so the button's touch target does not make
              // the card taller than its text.
              Transform.translate(
                offset: const Offset(Gap.sm, -Gap.sm),
                child: PopupMenuButton<_CardAction>(
                  icon: Icon(Icons.more_vert, color: scheme.outline),
                  tooltip: 'Další akce',
                  onSelected: (action) => switch (action) {
                    _CardAction.rename =>
                      renameMeetingFlow(context, ref, meeting),
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
      ),
    );
  }

  /// Only what is worth saying. A finished meeting whose transcript is complete
  /// gets no chips at all, which is what makes the ones that do stand out.
  List<Widget> _chips(bool isLive) {
    return [
      if (isLive)
        const StatusChip(
          icon: Icons.fiber_manual_record,
          label: 'Nahrává se',
          tone: ChipTone.alert,
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
          label:
              'Přepis ${summary.transcribedCount}/${summary.segmentCount}',
          tone: ChipTone.progress,
        ),
      if (summary.segmentCount == 0)
        const StatusChip(
          icon: Icons.mic_off_outlined,
          label: 'Bez záznamu',
        ),
      if (meeting.interrupted)
        const StatusChip(
          icon: Icons.power_settings_new,
          label: 'Přerušeno',
        ),
    ];
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isLive ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.md),
      ),
      child: Icon(
        isLive ? Icons.fiber_manual_record : Icons.description_outlined,
        size: 19,
        color: isLive ? scheme.error : scheme.onSurfaceVariant,
      ),
    );
  }
}

/// A full-width note above the list: something is wrong, or something is
/// missing that the user will want to fix before recording.
///
/// One widget rather than the two it replaces — a `ListTile` for the missing
/// key and a bare padded `Text` for a recording error — which had different
/// padding, different type and different colour for the same job.
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

    return Material(
      color: background,
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
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: foreground),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: Gap.xs),
                      Text(
                        message!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: foreground),
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
    );
  }
}
