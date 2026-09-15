import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/chat_intent.dart';
import '../../../ai/live_answer_service.dart';
import '../../../audio/recording_controller.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../data/db/tables/chat_messages_table.dart';
import '../meeting_detail_providers.dart';

/// The input pinned under the transcript: context, rules and questions typed
/// during a lesson, plus „Odpověz teď" while it is being recorded.
class ChatBar extends ConsumerStatefulWidget {
  const ChatBar({super.key, required this.meetingId, required this.recording});

  final int meetingId;
  final bool recording;

  @override
  ConsumerState<ChatBar> createState() => _ChatBarState();
}

class _ChatBarState extends ConsumerState<ChatBar> {
  final _controller = TextEditingController();
  bool _answering = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Where the message sorts into the transcript: the moment it was typed
  /// while recording, otherwise after everything already transcribed.
  int _atMs() {
    final startedAt = ref.read(recordingControllerProvider).startedAt;
    if (widget.recording && startedAt != null) {
      return DateTime.now().difference(startedAt).inMilliseconds;
    }
    final segments =
        ref.read(meetingSegmentsProvider(widget.meetingId)).valueOrNull;
    return segments == null || segments.isEmpty ? 0 : segments.last.endMs + 1;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final intent = detectChatIntent(text);
    final id = await ref.read(chatMessagesDaoProvider).addUserMessage(
          meetingId: widget.meetingId,
          text: text,
          intent: intent,
          atMs: _atMs(),
        );
    // Context and rules cost no request: the next answer call reads them.
    if (intent == ChatIntent.question) {
      unawaited(ref.read(chatAnswerServiceProvider).ask(id));
    }
  }

  Future<void> _answerNow() async {
    if (_answering) return;
    setState(() => _answering = true);

    final startedAt = ref.read(recordingControllerProvider).startedAt;
    final cutAtMs = startedAt == null
        ? null
        : DateTime.now().difference(startedAt).inMilliseconds;
    ref.read(recordingControllerProvider.notifier).cutNow();
    final outcome = await ref
        .read(liveAnswerServiceProvider)
        .answerNow(widget.meetingId, cutAtMs: cutAtMs);

    if (!mounted) return;
    setState(() => _answering = false);
    final message = switch (outcome) {
      AnswerNowOutcome.answered => null,
      AnswerNowOutcome.noQuestion =>
        'V poslední půlminutě jsem otázku nenašel.',
      AnswerNowOutcome.nothingHeard => 'Zatím nic nezaznělo.',
      AnswerNowOutcome.failed =>
        'Odpověď se nepodařilo získat. Zkus to za chvíli znovu.',
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.recording)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: FilledButton.tonalIcon(
                    onPressed: _answering ? null : _answerNow,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _answering
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt, size: 18),
                    label: Text(_answering ? 'Hledám otázku…' : 'Odpověz teď'),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: widget.recording
                            ? 'Kontext, otázka nebo pravidlo…'
                            : 'Zeptej se na přepis…',
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Gap.lg,
                          vertical: Gap.md,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.xs),
                  IconButton.filled(
                    onPressed: _send,
                    tooltip: 'Odeslat',
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
