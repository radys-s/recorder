import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/answer_source.dart';
import '../../../ai/chat_intent.dart';
import '../../../core/formatting.dart';
import '../../../core/paths.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/stored_photo.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/daos/subjects_dao.dart';
import '../../../data/db/tables/chat_messages_table.dart';
import '../../subjects/card_editor_screen.dart';
import '../meeting_detail_providers.dart';
import 'answer_card_tile.dart';

/// Czech name and icon of what a typed message is for.
({String label, IconData icon}) chatIntentChip(ChatIntent intent) =>
    switch (intent) {
      ChatIntent.context => (label: 'Kontext', icon: Icons.notes),
      ChatIntent.question => (label: 'Otázka', icon: Icons.help_outline),
      ChatIntent.rule => (label: 'Pravidlo', icon: Icons.rule),
      ChatIntent.photo => (label: 'Fotka', icon: Icons.photo_camera_outlined),
      ChatIntent.answerNow => (label: 'Odpověz teď', icon: Icons.bolt),
      ChatIntent.important => (label: 'Důležité', icon: Icons.star_rounded),
    };

/// One chat row in the transcript timeline.
class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) => message.role != ChatRole.user
      ? _AssistantReply(message: message)
      : message.intent == ChatIntent.important
      ? ImportantMarker(message: message)
      : message.intent == ChatIntent.photo && message.imagePath != null
      ? _PhotoBubble(message: message)
      : _UserBubble(message: message);
}

/// A card title from a board description: its first sentence, cut on a word.
String boardCardTitle(String description) {
  var title = description.trim();
  final dot = title.indexOf(RegExp(r'[.!?]\s'));
  if (dot > 0) title = title.substring(0, dot);
  title = title.replaceAll(RegExp(r'[.!?]+$'), '');
  const max = SubjectsDao.maxCardTitleLength;
  if (title.length > max) {
    final cut = title.lastIndexOf(' ', max);
    title = title.substring(0, cut > 20 ? cut : max);
  }
  return title.isEmpty ? 'Z tabule' : title;
}

class _PhotoBubble extends ConsumerStatefulWidget {
  const _PhotoBubble({required this.message});

  final ChatMessage message;

  @override
  ConsumerState<_PhotoBubble> createState() => _PhotoBubbleState();
}

class _PhotoBubbleState extends ConsumerState<_PhotoBubble> {
  bool _expanded = false;

  ChatMessage get _m => widget.message;

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Smazat fotku?',
      message: 'Zmizí i text z ní a AI ho přestane brát v úvahu.',
      confirmLabel: 'Smazat',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed) return;
    await ref.read(chatMessagesDaoProvider).deleteMessage(_m.id);
    try {
      final file = File(await resolveStoredPath(_m.imagePath!));
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Only disk space; the directory goes with the meeting anyway.
    }
  }

  void _saveToCard(int subjectId) {
    final description = _m.short ?? '';
    Navigator.of(context).push(
      CardEditorScreen.route(
        subjectId: subjectId,
        initialTitle: boardCardTitle(description),
        initialContent: _m.body.trim().isEmpty ? description : _m.body,
        initialImagePaths: [_m.imagePath!],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subjectId = ref
        .watch(meetingProvider(_m.meetingId))
        .valueOrNull
        ?.subjectId;
    final width = MediaQuery.sizeOf(context).width * 0.7;

    final Widget status = switch (_m.status) {
      ChatStatus.pending => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Gap.sm),
          Text('Čtu fotku…', style: theme.textTheme.bodySmall),
        ],
      ),
      ChatStatus.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _m.detail ?? 'Fotku se nepodařilo přečíst.',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
          TextButton.icon(
            onPressed: () => ref.read(boardPhotoServiceProvider).read(_m.id),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Zkusit znovu'),
          ),
        ],
      ),
      ChatStatus.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_m.short ?? '').isNotEmpty)
            Text(
              _m.short!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (_m.body.trim().isNotEmpty) ...[
            const SizedBox(height: Gap.xs),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _m.body,
                maxLines: _expanded ? null : 6,
                overflow: _expanded ? null : TextOverflow.fade,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
          ],
        ],
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => showStoredPhoto(context, _m.imagePath!),
                onLongPress: _delete,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: StoredPhoto(
                    storedPath: _m.imagePath!,
                    width: width,
                    height: width * 0.66,
                  ),
                ),
              ),
              const SizedBox(height: Gap.xs),
              if (_m.status == ChatStatus.ready)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: status,
                )
              else
                status,
              if (_m.status == ChatStatus.ready && subjectId != null)
                TextButton.icon(
                  onPressed: () => _saveToCard(subjectId),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Uložit do karty'),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
    if (confirmed) {
      await ref.read(chatMessagesDaoProvider).deleteMessage(message.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chip = chatIntentChip(message.intent);
    final cyclable =
        message.intent == ChatIntent.context ||
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
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

/// A ⭐ the student put on a moment of the lesson: a slim row with the time
/// and the optional note. Long-press takes the star away.
class ImportantMarker extends ConsumerWidget {
  const ImportantMarker({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = message.body.trim();
    return Semantics(
      label:
          'Důležité v ${formatClockMs(message.atMs)}'
          '${note.isEmpty ? '' : ': $note'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () async {
          final messenger = ScaffoldMessenger.of(context);
          await ref.read(chatMessagesDaoProvider).deleteMessage(message.id);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Hvězdička odebrána')));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Row(
            children: [
              Icon(Icons.star_rounded, size: 18, color: scheme.tertiary),
              const SizedBox(width: Gap.sm),
              Text(
                formatClockMs(message.atMs),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  note.isEmpty ? 'Důležité' : note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
