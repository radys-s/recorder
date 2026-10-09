import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/app_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/recording_controller.dart';
import '../../core/motion.dart';
import '../../core/formatting.dart';
import '../../core/listening_diagnostics.dart';
import '../../core/providers.dart';
import '../../core/share.dart';
import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/menu_row.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/db/app_database.dart';
import '../../data/db/tables/refined_segments_table.dart';
import '../../data/db/tables/transcript_segments_table.dart';
import '../../stt/refined_transcript.dart';
import '../meetings_list/meeting_actions.dart';
import '../subjects/subjects_providers.dart';
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
import 'widgets/transcription_wait_notice.dart';
import 'widgets/word_fix_sheet.dart';
import 'widgets/meeting_audio_player.dart';

enum _MeetingAction { lesson, rename, share, delete }

/// A single meeting and its transcript, growing live while recording.
class MeetingDetailScreen extends ConsumerStatefulWidget {
  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    this.focusSegmentId,
    this.initialTab = 0,
  });

  final int meetingId;
  final int initialTab;

  /// A transcript row to scroll to and mark, set when the screen is opened
  /// from a search hit rather than from the list.
  final int? focusSegmentId;

  /// Every push of this screen goes through [route], so the route carries a
  /// name — which is what lets the global recording banner tell "this meeting
  /// is already open, go back to it" from "it isn't, push it".
  static String routeNameFor(int meetingId) => 'meeting/$meetingId';

  static Route<void> route(
    int meetingId, {
    int? focusSegmentId,
    int initialTab = 0,
  }) => AppRoute<void>(
    settings: RouteSettings(name: routeNameFor(meetingId)),
    builder: (_) => MeetingDetailScreen(
      meetingId: meetingId,
      focusSegmentId: focusSegmentId,
      initialTab: initialTab,
    ),
  );

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  final _scrollController = ScrollController();

  /// Rows whose entrance has already played, as `seg:<id>` / `card:<id>`.
  /// Filled from the whole item list rather than from `itemBuilder`, because
  /// `itemBuilder` runs lazily: marking a row seen only when it is first built
  /// would replay the entrance for every old row the user scrolls up to.
  final _seen = <String>{};
  final _presentedAnswerCards = <int>{};

  /// The row a search hit asked for, until it has been brought into view.
  /// Scrolling to it is best-effort: a `ListView` builds lazily, so the target
  /// is first approached by a proportional jump and only then, once the row
  /// actually exists, aligned exactly.
  final _focusKey = GlobalKey();
  bool _focusDone = false;

  void _bringFocusedIntoView(List<Object> items) {
    final id = widget.focusSegmentId;
    if (id == null || _focusDone) return;
    final index = items.indexWhere((i) => i is TranscriptSegment && i.id == id);
    if (index < 0) return;
    _focusDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      _scrollController.jumpTo(
        position.maxScrollExtent * (index / items.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _focusKey.currentContext;
        if (ctx == null) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: reducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    });
  }

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
        duration: reducedMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// After the student sends a message: the bubble and the reply that follows
  /// belong on screen even when the reader had scrolled far up. Two frames, as
  /// the list first grows by the message and then by the pending reply.
  void _scrollToEnd() {
    void go() {
      if (!mounted || !_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      if (reducedMotion(context)) {
        _scrollController.jumpTo(end);
      } else {
        _scrollController.animateTo(
          end,
          duration: AppDuration.quick,
          curve: AppCurve.standard,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      go();
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
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
  /// Sends the transcript out as plain text — refined windows where they
  /// exist, live chunks where they do not, which is the same text the notes
  /// are written from.
  Future<void> _shareTranscript(BuildContext context, Meeting meeting) async {
    final messenger = ScaffoldMessenger.of(context);
    final segments = await ref
        .read(appDatabaseProvider)
        .transcriptSegmentsDao
        .segmentsForMeeting(widget.meetingId);
    final refined = await ref
        .read(refinedSegmentsDaoProvider)
        .windows(widget.meetingId);
    final text = refinedOrLiveTranscript(segments, refined);
    if (!context.mounted) return;
    if (text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Přepis je zatím prázdný.')),
      );
      return;
    }
    await shareText(context, title: meeting.title, content: text);
  }

  /// The recording controller watches the preference, so a lesson already
  /// running switches to the shorter chunks at its next cut.
  Future<void> _toggleLiveAnswers(bool enabled) =>
      ref.read(preferencesDaoProvider).setLiveAnswersEnabled(enabled);

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Presentation is the final observable hop. The listener has no UI side
    // effects; it only tells diagnostics whether a persisted card reached an
    // open detail screen. A card can still be read later in the timeline.
    ref.listen(answerCardsProvider(widget.meetingId), (_, next) {
      if (next.hasError) {
        ref
            .read(listeningDiagnosticsProvider)
            .record(
              ListeningStage.presentation,
              ListeningOutcome.failed,
              'answer_cards_stream_error',
              meetingId: widget.meetingId,
            );
        return;
      }
      for (final card in next.valueOrNull ?? const <AnswerCard>[]) {
        if (_presentedAnswerCards.add(card.id)) {
          ref
              .read(listeningDiagnosticsProvider)
              .record(
                ListeningStage.presentation,
                ListeningOutcome.accepted,
                'ui_presented',
                meetingId: widget.meetingId,
                segmentId: card.segmentId,
                metrics: {'card': card.id},
              );
        }
      }
    });
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
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: _MeetingTitle(meeting: meeting.valueOrNull),
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
                  ? () => _toggleLiveAnswers(!liveAnswers)
                  : null,
            ),
            PopupMenuButton<_MeetingAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Další akce',
              enabled: meeting.valueOrNull != null,
              onSelected: (action) => switch (action) {
                _MeetingAction.lesson => showLessonSheet(
                  context,
                  ref,
                  meeting.requireValue!,
                ),
                _MeetingAction.rename => renameMeetingFlow(
                  context,
                  ref,
                  meeting.requireValue!,
                ),
                _MeetingAction.share => _shareTranscript(
                  context,
                  meeting.requireValue!,
                ),
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
                const PopupMenuItem(
                  value: _MeetingAction.share,
                  child: MenuRow(icon: Icons.ios_share, label: 'Sdílet přepis'),
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
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Přepis'),
              Tab(
                text: meeting.valueOrNull?.subjectId != null
                    ? 'Výpisky'
                    : 'Poznámky',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // While the keyboard is up the header extras step aside — they are
            // kept mounted (a playing recording must not stop) but take no
            // height, so the transcript and the field keep the screen.
            _KeyboardCollapse(
              collapsed: keyboardOpen,
              child: Column(
                children: [
                  MeetingAudioPlayer(
                    segments:
                        ref
                            .watch(meetingSegmentsProvider(widget.meetingId))
                            .valueOrNull ??
                        const [],
                    audioCleared: meeting.valueOrNull?.audioClearedAt != null,
                  ),
                  if (meeting.valueOrNull?.interrupted == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: Gap.xs,
                      ),
                      child: Text(
                        'Nahrávání bylo přerušené. Část zvuku může chybět; zkontroluj přepis.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (meeting.valueOrNull case final m?)
                    LessonContextStrip(meeting: m),
                ],
              ),
            ),
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
    final latest = isThisOneRecording && newest != null && !newest.dismissed
        ? newest
        : null;

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
        TranscriptionWaitNotice(meetingId: widget.meetingId),
        _refinedHeader(recording: isThisOneRecording),
        Expanded(child: _transcriptList(isThisOneRecording, cards, messages)),
        // Stopping lives in the recording banner, so the bar has the bottom.
        ChatBar(
          meetingId: widget.meetingId,
          recording: isThisOneRecording,
          onSent: _scrollToEnd,
        ),
      ],
    );
  }

  Widget _transcriptList(
    bool isThisOneRecording,
    List<AnswerCard> cards,
    List<ChatMessage> messages,
  ) {
    final segments = ref.watch(meetingSegmentsProvider(widget.meetingId));
    // While recording, windows that are already done replace the live chunks
    // they cover; the chunks after the last window stay live.
    final refined =
        ref.watch(refinedSegmentsProvider(widget.meetingId)).valueOrNull ??
        const <RefinedSegment>[];
    final useRefined =
        !_showLive &&
        refined.any(
          (w) =>
              w.status == RefinedStatus.ready ||
              w.status == RefinedStatus.failed,
        );

    return AsyncView(
      value: segments,
      message: 'Přepis se nepodařilo načíst.',
      onRetry: () => ref.invalidate(meetingSegmentsProvider(widget.meetingId)),
      builder: (list) {
        // A sub-second tail chunk gets a row so the timeline stays complete,
        // but it holds no words and would render as an empty tile.
        final visible = list
            .where(
              (s) =>
                  s.status != SegmentStatus.transcribed ||
                  (s.content?.trim().isNotEmpty ?? false),
            )
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
        final items = useRefined
            ? withRefinedWindows(merged, list, refined)
            : merged;

        // A reply to a typed question is followed on a finished lesson too.
        if (items.length > _itemCount &&
            (isThisOneRecording || items.last is ChatMessage)) {
          _followTail();
        }
        _itemCount = items.length;
        _bringFocusedIntoView(items);

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
          // Dragging the transcript is the natural way to put the keyboard
          // away; without it the field stayed open until the app was left.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
          itemCount: items.length,
          // A rule butting up against a card reads as a mistake; between two
          // segments it is what keeps the transcript legible.
          separatorBuilder: (_, i) => _isText(items[i]) && _isText(items[i + 1])
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
                  key: item.id == widget.focusSegmentId ? _focusKey : null,
                  highlighted: item.id == widget.focusSegmentId,
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

  /// Refined-transcript controls: which transcript to read, how far the second
  /// pass is, and a way to run it again. While [recording] there is nothing to
  /// start or redo — the second pass follows the lesson on its own — so the
  /// header only appears once a window exists.
  Widget _refinedHeader({required bool recording}) {
    final refined = ref
        .watch(refinedSegmentsProvider(widget.meetingId))
        .valueOrNull;
    final segments = ref
        .watch(meetingSegmentsProvider(widget.meetingId))
        .valueOrNull;
    if (refined == null || segments == null || segments.isEmpty) {
      return const SizedBox.shrink();
    }
    final service = ref.read(refinedTranscriptServiceProvider);
    // Without the chunk WAVs there is nothing left to re-hear; the transcript
    // that exists is final.
    final cleared =
        ref
            .watch(meetingProvider(widget.meetingId))
            .valueOrNull
            ?.audioClearedAt !=
        null;

    if (refined.isEmpty) {
      if (recording) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: cleared
              ? Text(
                  'Zvuk už byl smazán, přepis nelze vylepšit.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : TextButton.icon(
                  onPressed: () => service.refine(widget.meetingId),
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Vylepšit přepis'),
                ),
        ),
      );
    }

    final ready = refined.where((w) => w.status == RefinedStatus.ready).length;
    final failed = refined
        .where((w) => w.status == RefinedStatus.failed)
        .length;
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
                    label:
                        'Vylepšuji přepis ${ready + failed}/${refined.length}',
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
            tooltip: cleared ? 'Zvuk už byl smazán' : 'Přepsat znovu',
            onPressed: working > 0 || cleared || recording
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

/// A lesson nobody renamed is titled „Hodina 28.9. 8:00", which says when but
/// not what. The subject is what the student looks for, so it leads and the
/// date moves to a quiet second line.
/// Lets [child] shrink to nothing while the keyboard is open without
/// unmounting it, so audio that is playing keeps playing.
class _KeyboardCollapse extends StatelessWidget {
  const _KeyboardCollapse({required this.collapsed, required this.child});

  final bool collapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSize(
        duration: reducedMotion(context) ? Duration.zero : AppDuration.quick,
        curve: AppCurve.standard,
        alignment: Alignment.topCenter,
        child: Visibility(
          visible: !collapsed,
          maintainState: true,
          child: child,
        ),
      ),
    );
  }
}

class _MeetingTitle extends ConsumerWidget {
  const _MeetingTitle({required this.meeting});

  final Meeting? meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = meeting;
    if (m == null) return const Text('Schůzka');
    final subjectId = m.subjectId;
    final subject = subjectId == null
        ? null
        : ref.watch(subjectProvider(subjectId)).valueOrNull;
    if (subject == null || !isDefaultMeetingTitle(m.title)) {
      return Text(m.title, overflow: TextOverflow.ellipsis);
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(subject.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          formatMeetingDate(m.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
