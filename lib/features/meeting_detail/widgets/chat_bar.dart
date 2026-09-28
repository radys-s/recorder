import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accent.dart';
import '../../../ai/chat_intent.dart';
import '../../../ai/live_answer_service.dart';
import '../../../audio/recording_controller.dart';
import '../../../core/paths.dart';
import '../../../core/photo_files.dart';
import '../../../core/photo_picker.dart';
import '../../../core/providers.dart';
import '../../../core/spacing.dart';
import '../../../data/db/tables/chat_messages_table.dart';
import '../lesson_photos.dart';
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
    final segments = ref
        .read(meetingSegmentsProvider(widget.meetingId))
        .valueOrNull;
    return segments == null || segments.isEmpty ? 0 : segments.last.endMs + 1;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final intent = detectChatIntent(text);
    final id = await ref
        .read(chatMessagesDaoProvider)
        .addUserMessage(
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

  /// ⭐ on this moment of the lesson. Whatever is typed becomes its note, so
  /// „tohle bude v testu" is one tap away from being remembered in výpisky.
  Future<void> _markImportant() async {
    final note = _controller.text.trim();
    _controller.clear();
    unawaited(HapticFeedback.mediumImpact());
    await ref
        .read(chatMessagesDaoProvider)
        .addImportant(meetingId: widget.meetingId, atMs: _atMs(), note: note);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Označeno jako důležité'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  /// Photos of the board or the slides: stored and shown at once, read by
  /// Gemini in the background. They become lesson context, so no answer is
  /// generated. Also after the lesson, for slides that arrive later.
  Future<void> _addPhotos() async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    ref.invalidate(hasVisionKeyProvider);
    if (!await ref.read(hasVisionKeyProvider.future)) {
      say('Fotky čte Gemini nebo Mistral. Přidej klíč v Nastavení.');
      return;
    }
    // The moment of the tap, not of the shutter: that is when it was shown.
    final atMs = _atMs();
    if (!mounted) return;
    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Vyfotit'),
              subtitle: const Text('Tabule, slide nebo papír'),
              onTap: () => Navigator.pop(context, _PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Vybrat z galerie'),
              subtitle: const Text('Třeba snímky prezentace, víc najednou'),
              onTap: () => Navigator.pop(context, _PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ref.read(photoPickerProvider);
    final List<PickedPhoto> photos;
    try {
      photos = switch (source) {
        _PhotoSource.camera => [?await picker.takePhoto()],
        _PhotoSource.gallery => await picker.pickPages(),
      };
    } on PlatformException {
      say(
        'Fotoaparát nebo fotky nejsou dostupné. Povol je v Nastavení iPhonu.',
      );
      return;
    }
    if (photos.isEmpty) return;

    final docs = await documentsPath();
    final added = await addLessonPhotos(
      photos: photos,
      meetingId: widget.meetingId,
      atMs: atMs,
      chat: ref.read(chatMessagesDaoProvider),
      store: (photo) => savePhoto(
        docsPath: docs,
        dir: meetingPhotosDir(docs, widget.meetingId),
        bytes: photo.bytes,
        extension: photo.extension,
      ),
    );
    final reader = ref.read(boardPhotoServiceProvider);
    for (final id in added.ids) {
      unawaited(reader.read(id));
    }
    if (added.failed > 0) {
      say(
        added.ids.isEmpty
            ? 'Fotku se nepodařilo uložit.'
            : 'Některé fotky se nepodařilo uložit (${added.failed}).',
      );
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

    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );

    // A floating capsule rather than a band across the bottom edge.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
        child: Material(
          color: scheme.surfaceContainerHigh,
          elevation: 3,
          shadowColor: scheme.shadow.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(Gap.sheetRadius),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(Gap.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.recording)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.sm,
                      Gap.xs,
                      Gap.sm,
                      Gap.xs,
                    ),
                    child: Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _answering ? null : _answerNow,
                          style: tonalButtonStyle(context).merge(
                            FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          icon: _answering
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.bolt, size: 18),
                          label: Text(
                            _answering ? 'Hledám otázku…' : 'Odpověz teď',
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        OutlinedButton.icon(
                          onPressed: _markImportant,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: scheme.tertiary,
                          ),
                          label: const Text('Důležité'),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _addPhotos,
                      tooltip: 'Fotka tabule nebo prezentace',
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
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
                          border: pill,
                          enabledBorder: pill,
                          focusedBorder: pill,
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
      ),
    );
  }
}

enum _PhotoSource { camera, gallery }
