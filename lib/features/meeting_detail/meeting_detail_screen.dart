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
import '../../data/db/app_database.dart';
import '../../data/db/tables/transcript_segments_table.dart';
import 'meeting_detail_providers.dart';
import 'widgets/answer_card_tile.dart';
import 'widgets/latest_answer_panel.dart';
import 'widgets/meeting_notes_tab.dart';
import 'widgets/transcript_segment_tile.dart';

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

  /// Follows the transcript only while this meeting is the one being recorded.
  /// Scrolling a finished transcript out from under someone reading it would
  /// be worse than not following at all.
  void _followTail() {
    if (!_scrollController.hasClients) return;
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
    final recording = ref.watch(recordingControllerProvider);
    final isThisOneRecording =
        recording.isRecording && recording.meetingId == widget.meetingId;
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
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Přepis'),
              Tab(text: 'Poznámky'),
            ],
          ),
        ),
        floatingActionButton: isThisOneRecording
            ? FloatingActionButton.extended(
                onPressed: () =>
                    ref.read(recordingControllerProvider.notifier).stop(),
                icon: const Icon(Icons.stop),
                label: const Text('Zastavit'),
              )
            : null,
        body: TabBarView(
          children: [
            _buildTranscript(isThisOneRecording),
            MeetingNotesTab(meetingId: widget.meetingId),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscript(bool isThisOneRecording) {
    final cards =
        ref.watch(answerCardsProvider(widget.meetingId)).valueOrNull ??
            const <AnswerCard>[];

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
        Expanded(child: _transcriptList(isThisOneRecording, cards)),
      ],
    );
  }

  Widget _transcriptList(bool isThisOneRecording, List<AnswerCard> cards) {
    final segments = ref.watch(meetingSegmentsProvider(widget.meetingId));
    if (isThisOneRecording) _followTail();

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

        if (visible.isEmpty) {
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

        // Cards are merged into the timeline right after the segment their
        // question was heard in, so the answer sits where it was asked. The
        // existing auto-scroll then brings it into view for free.
        final bySegment = <int, List<AnswerCard>>{};
        for (final card in cards) {
          (bySegment[card.segmentId] ??= <AnswerCard>[]).add(card);
        }

        final items = <Object>[];
        for (final segment in visible) {
          items.add(segment);
          final own = bySegment[segment.id];
          if (own != null) items.addAll(own);
        }

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
              Gap.lg, Gap.sm, Gap.lg, Gap.fabClearance),
          itemCount: items.length,
          // A rule butting up against a card reads as a mistake; between two
          // segments it is what keeps the transcript legible.
          separatorBuilder: (_, i) =>
              items[i] is AnswerCard || items[i + 1] is AnswerCard
                  ? const SizedBox.shrink()
                  : const Divider(height: 1),
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
                TranscriptSegment() => TranscriptSegmentTile(
                    segment: item,
                    onRetry: () => _retry(item),
                  ),
                _ => const SizedBox.shrink(),
              },
            );
          },
        );
      },
    );
  }

  static String _rowKey(Object item) => item is AnswerCard
      ? 'card:${item.id}'
      : 'seg:${(item as TranscriptSegment).id}';
}
