import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/recording_controller.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/menu_row.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/db/app_database.dart';
import '../../data/db/tables/refined_segments_table.dart';
import '../../data/db/tables/transcript_segments_table.dart';
import '../meetings_list/meeting_actions.dart';
import '../subjects/widgets/lesson_context_strip.dart';
import '../subjects/widgets/lesson_sheet.dart';
import 'meeting_detail_providers.dart';
import 'timeline.dart';
import 'widgets/answer_card_tile.dart';
import 'widgets/chat_bar.dart';
import 'widgets/chat_message_tile.dart';
import 'widgets/latest_answer_panel.dart';
import 'widgets/meeting_notes_tab.dart';
import 'widgets/refined_window_tile.dart';
import 'widgets/transcript_segment_tile.dart';
import 'widgets/word_fix_sheet.dart';

enum _MeetingAction { lesson, rename, delete }

/// A single meeting and its transcript, growing live while recording.
class MeetingDetailScreen extends ConsumerStatefulWidget {
  const MeetingDetailScreen({super.key, required this.meetingId});

  final int meetingId;

  /// Every push of this screen goes through [route], so the route carries a
  /// name — which is what lets the global recording banner tell "this meeting
  /// is already open, go back to it" from "it isn't, push it".
  static String routeNameFor(int meetingId) => 'meeting/$meetingId';

  static Route<void> route(int meetingId) => MaterialPageRoute<void>(
        settings: RouteSettings(name: routeNameFor(meetingId)),
        builder: (_) => MeetingDetailScreen(meetingId: meetingId),
      );

  @override
  ConsumerState<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  final _scrollController = ScrollController();

  /// Rows whose entrance has already played, as `seg:<id>` / `card:<id>`.
  /// Filled from the whole item list rather than from `itemBuilder`, because
  /// `itemBuilder` runs lazily: marking a row seen only when it is first built
  /// would replay the entrance for every old row the user scrolls up to.
  final _seen = <String>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// How many rows the transcript had at the last build; the tail is followed
  /// only when that grows.
  int _itemCount = 0;

  /// The student chose the live transcript over the refined one.
  bool _showLive = false;

  /// Follows the transcript only while this meeting is the one being recorded,
  /// only when a row was added, and only for a reader already at the bottom.
  /// It used to run on every build — and a build came with every audio buffer —
  /// so scrolling up to reread something mid-meeting was yanked straight back.
  void _followTail() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > 160) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _retry(TranscriptSegment segment) async {
    final db = ref.read(appDatabaseProvider);
    await db.uploadQueueDao.requeueForSegment(segment.id);
    await db.transcriptSegmentsDao.updateSegmentStatus(
      segment.id,
      SegmentStatus.pending,
    );
    unawaited(ref.read(queueWorkerProvider).poke());
  }

  Future<void> _dismissCard(int cardId) =>
      ref.read(answerCardsDaoProvider).dismiss(cardId);

  /// The app-bar toggle writes the same global preference Settings does — one
  /// setting, two places to reach it.
  Future<void> _toggleLiveAnswers(bool enabled, bool recordingNow) async {
    await ref.read(preferencesDaoProvider).setLiveAnswersEnabled(enabled);
    if (!mounted || !enabled || !recordingNow) return;

    // Turning it on mid-recording is a half-measure and saying so beats
    // letting the user wonder why answers are slow: the chunk length was
    // fixed when the recording started, so answers will arrive at the normal
    // 15-30 s cadence rather than the fast one.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Odpovědi se zapnuly. Kratší úseky zvuku se nastavují na začátku '
            'nahrávání, takže teď přijdou pomaleji.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final meeting = ref.watch(meetingProvider(widget.meetingId));
    final isThisOneRecording = ref.watch(
      recordingControllerProvider.select(
        (s) => s.isRecording && s.meetingId == widget.meetingId,
      ),
    );
    final prefs = ref.watch(preferencesProvider);
    final liveAnswers = prefs.valueOrNull?.liveAnswersEnabled ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(meeting.valueOrNull?.title ?? 'Schůzka'),
          actions: [
            IconButton(
              // The two icons differ only in fill, so a hard swap reads as a
              // glitch rather than as a state change. Scaling through the
              // change makes it legible without drawing attention.
              icon: AnimatedSwitcher(
                duration: reducedMotion(context)
                    ? Duration.zero
                    : AppDuration.quick,
                switchInCurve: AppCurve.standard,
                switchOutCurve: AppCurve.exit,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  liveAnswers ? Icons.lightbulb : Icons.lightbulb_outline,
                  key: ValueKey(liveAnswers),
                ),
              ),
              tooltip: liveAnswers
                  ? 'Živé odpovědi jsou zapnuté'
                  : 'Živé odpovědi jsou vypnuté',
              onPressed: prefs.hasValue
                  ? () => _toggleLiveAnswers(!liveAnswers, isThisOneRecording)
                  : null,
            ),
            PopupMenuButton<_MeetingAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Další akce',
              enabled: meeting.valueOrNull != null,
              onSelected: (action) => switch (action) {
                _MeetingAction.lesson =>
                  showLessonSheet(context, ref, meeting.requireValue!),
                _MeetingAction.rename =>
                  renameMeetingFlow(context, ref, meeting.requireValue!),
                _MeetingAction.delete => confirmAndDeleteMeeting(
                    context,
                    ref,
                    meetingId: widget.meetingId,
                    popRoute: true,
                  ),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _MeetingAction.lesson,
                  child: MenuRow(
                    icon: Icons.school_outlined,
                    label: 'Předmět a karty',
                  ),
                ),
                const PopupMenuItem(
                  value: _MeetingAction.rename,
                  child: MenuRow(
                    icon: Icons.drive_file_rename_outline,
                    label: 'Přejmenovat',
                  ),
                ),
                PopupMenuItem(
                  value: _MeetingAction.delete,
                  enabled: !isThisOneRecording,
                  child: MenuRow(
                    icon: Icons.delete_outline,
                    label: 'Smazat schůzku',
                    destructive: true,
                    enabled: !isThisOneRecording,
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Přepis'),
              Tab(text: 'Poznámky'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (meeting.valueOrNull case final m?) LessonContextStrip(meeting: m),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTranscript(isThisOneRecording),
                  MeetingNotesTab(meetingId: widget.meetingId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscript(bool isThisOneRecording) {
    final cards =
        ref.watch(answerCardsProvider(widget.meetingId)).valueOrNull ??
            const <AnswerCard>[];
    final messages =
        ref.watch(chatMessagesProvider(widget.meetingId)).valueOrNull ??
            const <ChatMessage>[];

    // The newest card, pinned only while this meeting is the one recording —
    // on a finished meeting the timeline cards are the record and a panel
    // would just be in the way.
    //
    // Dismissing it hides the panel until a *newer* answer arrives; falling
    // back to the previous card would mean "hide this" resurfacing something
    // already read, and the user dismissing the whole meeting one card at a
    // time.
    final newest = cards.isEmpty ? null : cards.last;
    final latest =
        isThisOneRecording && newest != null && !newest.dismissed ? newest : null;

    final reduced = reducedMotion(context);

    return Column(
      children: [
        // The panel arrives unannounced in the middle of a scrolling list, so
        // it opens rather than appearing: the transcript is pushed down and the
        // answer fades in behind it. Keyed by card id, so a newer answer
        // replacing an older one gets the same treatment.
        AnimatedSwitcher(
          duration: reduced ? Duration.zero : AppDuration.base,
          switchInCurve: AppCurve.standard,
          switchOutCurve: AppCurve.exit,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: latest == null
              ? const SizedBox(key: ValueKey('none'), width: double.infinity)
              : LatestAnswerPanel(
                  key: ValueKey(latest.id),
                  card: latest,
                  onDismiss: () => _dismissCard(latest.id),
                ),
        ),
        if (!isThisOneRecording) _refinedHeader(),
        Expanded(
          child: _transcriptList(isThisOneRecording, cards, messages),
        ),
        // Stopping lives in the recording banner, so the bar has the bottom.
        ChatBar(meetingId: widget.meetingId, recording: isThisOneRecording),
      ],
    );
  }

  Widget _transcriptList(
    bool isThisOneRecording,
    List<AnswerCard> cards,
    List<ChatMessage> messages,
  ) {
    final segments = ref.watch(meetingSegmentsProvider(widget.meetingId));
    final refined = isThisOneRecording
        ? const <RefinedSegment>[]
        : ref.watch(refinedSegmentsProvider(widget.meetingId)).valueOrNull ??
            const <RefinedSegment>[];
    final useRefined = !_showLive &&
        refined.any((w) =>
            w.status == RefinedStatus.ready ||
            w.status == RefinedStatus.failed);

    return AsyncView(
      value: segments,
      message: 'Přepis se nepodařilo načíst.',
      onRetry: () =>
          ref.invalidate(meetingSegmentsProvider(widget.meetingId)),
      builder: (list) {
        // A sub-second tail chunk gets a row so the timeline stays complete,
        // but it holds no words and would render as an empty tile.
        final visible = list
            .where((s) =>
                s.status != SegmentStatus.transcribed ||
                (s.content?.trim().isNotEmpty ?? false))
            .toList();

        if (visible.isEmpty && messages.isEmpty && !useRefined) {
          return EmptyState(
            icon: isThisOneRecording
                ? Icons.graphic_eq
                : Icons.subject_outlined,
            title: isThisOneRecording
                ? 'Poslouchám…'
                : 'Zatím tu není žádný přepis',
            message: isThisOneRecording
                ? 'První část přepisu se objeví, jakmile řeč na chvíli '
                    'utichne.'
                : null,
          );
        }

        // Answers sit right after the segment their question was heard in,
        // chat messages where they were typed.
        final merged = mergeTimeline(visible, cards, messages);
        final items =
            useRefined ? withRefinedWindows(merged, list, refined) : merged;

        // A reply to a typed question is followed on a finished lesson too.
        if (items.length > _itemCount &&
            (isThisOneRecording || items.last is ChatMessage)) {
          _followTail();
        }
        _itemCount = items.length;

        // Which rows are new *this* build, and in what order — so the first
        // paint of an already-recorded meeting reads as a sequence, while a
        // single segment arriving mid-recording appears straight away.
        final firstPaint = _seen.isEmpty;
        final entering = <String, int>{};
        for (final item in items) {
          final key = _rowKey(item);
          if (_seen.add(key)) entering[key] = entering.length;
        }

        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
              Gap.lg, Gap.sm, Gap.lg, Gap.lg),
          itemCount: items.length,
          // A rule butting up against a card reads as a mistake; between two
          // segments it is what keeps the transcript legible.
          separatorBuilder: (_, i) =>
              _isText(items[i]) && _isText(items[i + 1])
                  ? const Divider(height: 1)
                  : const SizedBox.shrink(),
          itemBuilder: (_, i) {
            final item = items[i];
            final order = entering[_rowKey(item)];

            return Entrance(
              enabled: order != null,
              delay: firstPaint && order != null
                  ? AppMotion.staggerDelay(order)
                  : Duration.zero,
              child: switch (item) {
                AnswerCard() => AnswerCardTile(card: item),
                ChatMessage() => ChatMessageTile(message: item),
                RefinedSegment() => RefinedWindowTile(
                    window: item,
                    onRetry: () => ref
                        .read(refinedTranscriptServiceProvider)
                        .retryWindow(item.id),
                    onLongPress: isThisOneRecording
                        ? null
                        : () => showWordFixSheet(
                              context,
                              meetingId: widget.meetingId,
                              text: item.content?.trim() ?? '',
                              original: item.rawContent,
                              onRestore: () => ref
                                  .read(appDatabaseProvider)
                                  .refinedSegmentsDao
                                  .restoreWindow(item.id),
                            ),
                  ),
                TranscriptSegment() => TranscriptSegmentTile(
                    segment: item,
                    onRetry: () => _retry(item),
                    onLongPress: () => showWordFixSheet(
                      context,
                      meetingId: widget.meetingId,
                      text: item.content ?? '',
                      original: item.rawContent,
                      onRestore: () => ref
                          .read(appDatabaseProvider)
                          .transcriptSegmentsDao
                          .restoreSegment(item.id),
                    ),
                  ),
                _ => const SizedBox.shrink(),
              },
            );
          },
        );
      },
    );
  }

  static bool _isText(Object item) =>
      item is TranscriptSegment || item is RefinedSegment;

  /// Refined-transcript controls on a finished meeting: which transcript to
  /// read, how far the second pass is, and a way to run it again.
  Widget _refinedHeader() {
    final refined =
        ref.watch(refinedSegmentsProvider(widget.meetingId)).valueOrNull;
    final segments =
        ref.watch(meetingSegmentsProvider(widget.meetingId)).valueOrNull;
    if (refined == null || segments == null || segments.isEmpty) {
      return const SizedBox.shrink();
    }
    final service = ref.read(refinedTranscriptServiceProvider);

    if (refined.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => service.refine(widget.meetingId),
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Vylepšit přepis'),
          ),
        ),
      );
    }

    final ready = refined.where((w) => w.status == RefinedStatus.ready).length;
    final failed =
        refined.where((w) => w.status == RefinedStatus.failed).length;
    final working = refined.length - ready - failed;
    final canToggle = ready + failed > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, 0),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (canToggle)
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment(value: false, label: Text('Vylepšený')),
                      ButtonSegment(value: true, label: Text('Živý')),
                    ],
                    selected: {_showLive},
                    onSelectionChanged: (set) =>
                        setState(() => _showLive = set.first),
                  ),
                if (working > 0)
                  StatusChip(
                    icon: Icons.auto_fix_high,
                    label: 'Vylepšuji přepis ${ready + failed}/${refined.length}',
                    tone: ChipTone.progress,
                  )
                else if (failed > 0)
                  StatusChip(
                    icon: Icons.error_outline,
                    label: '$failed× nevylepšeno',
                    tone: ChipTone.alert,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Přepsat znovu',
            onPressed: working > 0
                ? null
                : () => service.refine(widget.meetingId, force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  static String _rowKey(Object item) => switch (item) {
        RefinedSegment() => 'win:${item.id}',
        AnswerCard() => 'card:${item.id}',
        ChatMessage() => 'msg:${item.id}',
        TranscriptSegment() => 'seg:${item.id}',
        _ => 'other:${item.hashCode}',
      };
}
