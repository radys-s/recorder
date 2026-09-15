import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/answer_source.dart';
import '../../../ai/chat_intent.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/tables/chat_messages_table.dart';
import 'answer_card_tile.dart';

/// Czech name and icon of what a typed message is for.
({String label, IconData icon}) chatIntentChip(ChatIntent intent) =>
    switch (intent) {
      ChatIntent.context => (label: 'Kontext', icon: Icons.notes),
      ChatIntent.question => (label: 'Otázka', icon: Icons.help_outline),
      ChatIntent.rule => (label: 'Pravidlo', icon: Icons.rule),
      ChatIntent.photo => (label: 'Fotka', icon: Icons.photo_camera_outlined),
      ChatIntent.answerNow => (label: 'Odpověz teď', icon: Icons.bolt),
    };

/// One chat row in the transcript timeline.
class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) => message.role == ChatRole.user
      ? _UserBubble(message: message)
      : _AssistantReply(message: message);
}

class _UserBubble extends ConsumerWidget {
  const _UserBubble({required this.message});

  final ChatMessage message;

  Future<void> _cycleIntent(WidgetRef ref) async {
    final dao = ref.read(chatMessagesDaoProvider);
    final next = cycleChatIntent(message.intent);
    await dao.setIntent(message.id, next);
    // Re-marking a message as a question is asking it.
    if (next == ChatIntent.question && await dao.replyTo(message.id) == null) {
      unawaited(ref.read(chatAnswerServiceProvider).ask(message.id));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Smazat zprávu?',
      message: 'Zmizí i s odpovědí a AI ji přestane brát v úvahu.',
      confirmLabel: 'Smazat',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed) await ref.read(chatMessagesDaoProvider).deleteMessage(message.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chip = chatIntentChip(message.intent);
    final cyclable = message.intent == ChatIntent.context ||
        message.intent == ChatIntent.question ||
        message.intent == ChatIntent.rule;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onLongPress: () => _delete(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: Gap.sm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    message.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.xs),
              Tooltip(
                message: cyclable
                    ? 'Klepnutím změníš, k čemu zpráva je'
                    : chip.label,
                child: ActionChip(
                  avatar: Icon(chip.icon, size: 16),
                  label: Text(chip.label),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: cyclable ? () => _cycleIntent(ref) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantReply extends ConsumerWidget {
  const _AssistantReply({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (message.status) {
      case ChatStatus.pending:
        return Card(
          color: scheme.secondaryContainer,
          margin: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: Gap.md),
                Text(
                  'Přemýšlím…',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
        );
      case ChatStatus.failed:
        final replyTo = message.replyTo;
        return Card(
          color: scheme.errorContainer,
          margin: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.sm, Gap.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.body.isEmpty
                      ? 'Odpověď se nepodařilo získat.'
                      : message.body,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
                if (replyTo != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          ref.read(chatAnswerServiceProvider).ask(replyTo),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Zkusit znovu'),
                    ),
                  ),
              ],
            ),
          ),
        );
      case ChatStatus.ready:
        return AnswerBubble(
          question: null,
          short: message.short ?? message.body,
          detail: message.detail,
          basis: message.basis ?? 'meeting',
          sources: decodeAnswerSources(message.sources),
          icon: Icons.chat_bubble_outline,
        );
    }
  }
}
