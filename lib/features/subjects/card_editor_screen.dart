import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/answer_source.dart';
import '../../ai/card_lookup_service.dart';
import '../../ai/gemini_provider.dart';
import '../../ai/photo_text_service.dart';
import '../../core/logging.dart';
import '../../core/paths.dart';
import '../../core/pending_deletions.dart';
import '../../core/photo_files.dart';
import '../../core/photo_picker.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/menu_row.dart';
import '../../core/widgets/stored_photo.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/subjects_dao.dart';
import '../../data/db/tables/context_cards_table.dart';
import '../meeting_detail/widgets/answer_sources.dart';
import 'subjects_providers.dart';

enum _CardAction { delete }

enum _PhotoSource { camera, gallery }

enum _Merge { replace, append }

/// Creates a context card, or edits [card] when one is given.
///
/// A card is what the AI reads during a lesson: a book, a topic, a set of
/// terms. The content is free text on purpose — the student writes it the way
/// they think about it, and the AI copes with any shape. „Z fotky" and
/// „Dohledat" only append to that text; the student edits before saving.
class CardEditorScreen extends ConsumerStatefulWidget {
  const CardEditorScreen({
    super.key,
    required this.subjectId,
    this.card,
    this.initialTitle,
    this.initialContent,
    this.initialImagePaths = const [],
  });

  final int subjectId;
  final ContextCard? card;

  /// Prefill for a new card, e.g. from a board photo in the lesson chat.
  final String? initialTitle;
  final String? initialContent;

  /// Stored photos copied into the new card on save.
  final List<String> initialImagePaths;

  static Route<void> route({
    required int subjectId,
    ContextCard? card,
    String? initialTitle,
    String? initialContent,
    List<String> initialImagePaths = const [],
  }) =>
      MaterialPageRoute<void>(
        builder: (_) => CardEditorScreen(
          subjectId: subjectId,
          card: card,
          initialTitle: initialTitle,
          initialContent: initialContent,
          initialImagePaths: initialImagePaths,
        ),
      );

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  static const _tag = 'cards.editor';

  late final _title = TextEditingController(
    text: widget.card?.title ?? widget.initialTitle ?? '',
  );
  late final _content = TextEditingController(
    text: widget.card?.content ?? widget.initialContent ?? '',
  );
  late final String? _savedSources = widget.card?.sources;
  late List<AnswerSource> _sources = decodeAnswerSources(_savedSources);

  /// Photos already stored on this card.
  List<String> _storedImages = const [];

  /// Pages read in this session, stored on save.
  final _newPages = <PickedPhoto>[];

  bool _saving = false;
  bool _usedPhotos = false;
  bool _usedLookup = false;

  /// What is running right now („Čtu fotky…"), or null.
  String? _busy;

  /// Stops the running Gemini call when the student gives up waiting.
  CancelToken? _cancel;

  bool get _isNew => widget.card == null;

  bool get _dirty =>
      _title.text.trim() != (widget.card?.title ?? '') ||
      _content.text.trim() != (widget.card?.content ?? '') ||
      _newPages.isNotEmpty ||
      (_isNew && widget.initialImagePaths.isNotEmpty) ||
      encodeAnswerSources(_sources) != _savedSources;

  @override
  void initState() {
    super.initState();
    // The key may have been saved in Settings while an older answer to "is
    // there a key" was cached; the hint below must not claim there is none.
    Future.microtask(() {
      if (mounted) ref.invalidate(hasGeminiKeyProvider);
    });
    final card = widget.card;
    if (card != null) {
      ref.read(subjectsDaoProvider).cardImagePaths(card.id).then((paths) {
        if (mounted) setState(() => _storedImages = paths);
      });
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _append(String text) {
    final current = _content.text.trimRight();
    _content.text = current.isEmpty ? text : '$current\n\n$text';
  }

  void _stop() {
    _cancel?.cancel();
    setState(() => _busy = null);
  }

  /// Whether a found text replaces what the card already holds.
  Future<_Merge?> _askMerge() async {
    if (_content.text.trim().isEmpty) return _Merge.append;
    return showModalBottomSheet<_Merge>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Přidat na konec'),
              subtitle: const Text('Co už v kartě je, zůstane.'),
              onTap: () => Navigator.pop(context, _Merge.append),
            ),
            ListTile(
              leading: const Icon(Icons.find_replace),
              title: const Text('Nahradit obsah'),
              subtitle: const Text('Dosavadní text karty se přepíše.'),
              onTap: () => Navigator.pop(context, _Merge.replace),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fromPhotos() async {
    if (_busy != null) return;
    ref.invalidate(hasVisionKeyProvider);
    if (!await ref.read(hasVisionKeyProvider.future)) {
      if (mounted) {
        ref.invalidate(hasGeminiKeyProvider);
        _say('Text z fotek čte Gemini nebo Mistral. Přidej klíč v Nastavení.');
      }
      return;
    }
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
              title: const Text('Vyfotit stránku'),
              onTap: () => Navigator.pop(context, _PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Vybrat z galerie'),
              subtitle: const Text('Víc stránek najednou, v pořadí výběru'),
              onTap: () => Navigator.pop(context, _PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ref.read(photoPickerProvider);
    final List<PickedPhoto> pages;
    try {
      pages = switch (source) {
        _PhotoSource.camera => [?await picker.takePhoto()],
        _PhotoSource.gallery => await picker.pickPages(),
      };
    } on PlatformException {
      if (mounted) {
        _say('Fotoaparát nebo fotky nejsou dostupné. Povol je v Nastavení iPhonu.');
      }
      return;
    }
    if (pages.isEmpty || !mounted) return;

    final cancel = _cancel = CancelToken();
    setState(() => _busy = pages.length == 1 ? 'Čtu fotku…' : 'Čtu ${pages.length} fotky…');
    try {
      final text = await ref.read(photoTextServiceProvider).transcribePages(
        [
          for (final page in pages)
            LlmImage(page.bytes, mimeType: page.mimeType),
        ],
        cancelToken: cancel,
      );
      if (!mounted || cancel.isCancelled) return;
      setState(() {
        _append(text);
        _newPages.addAll(pages);
        _usedPhotos = true;
      });
    } catch (e, st) {
      if (cancel.isCancelled) return;
      AppLog.e(_tag, 'pages not read', e, st);
      if (mounted) _say(geminiFailureText(e));
    } finally {
      if (mounted && identical(_cancel, cancel)) {
        setState(() => _busy = null);
      }
    }
  }

  Future<void> _lookUp() async {
    if (_busy != null) return;
    final query = _title.text.trim();
    if (query.isEmpty) {
      _say('Napiš do názvu, co mám dohledat — třeba „Babička, Božena Němcová".');
      return;
    }
    FocusScope.of(context).unfocus();
    final merge = await _askMerge();
    if (merge == null || !mounted) return;
    final cancel = _cancel = CancelToken();
    setState(() => _busy = 'Dohledávám…');
    try {
      final subject =
          await ref.read(subjectsDaoProvider).subject(widget.subjectId);
      final found = await ref
          .read(cardLookupServiceProvider)
          .lookUp(query, subjectName: subject?.name, cancelToken: cancel);
      if (!mounted || cancel.isCancelled) return;
      setState(() {
        if (merge == _Merge.replace) {
          _content.text = found.content;
          _sources = found.sources;
        } else {
          _append(found.content);
          _sources = mergeCardSources(_sources, found.sources);
        }
        _usedLookup = true;
      });
      final problem = found.geminiProblem;
      if (problem != null) {
        _say('Přes Gemini to nešlo, dohledáno stručně přes Groq. $problem');
      } else if (!found.viaGemini) {
        _say('Dohledáno jen stručně. S Gemini klíčem v Nastavení to bude podrobnější.');
      } else if (found.truncated) {
        _say('Karta je dlouhá a konec se nevešel — zkontroluj poslední část.');
      } else if (!found.grounded) {
        _say('Gemini tentokrát nehledal na webu — ověř fakta.');
      }
    } catch (e, st) {
      if (cancel.isCancelled) return;
      AppLog.e(_tag, 'lookup failed', e, st);
      if (mounted) _say(geminiFailureText(e));
    } finally {
      if (mounted && identical(_cancel, cancel)) {
        setState(() => _busy = null);
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _busy != null || _title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final dao = ref.read(subjectsDaoProvider);
    final digests = ref.read(cardDigestServiceProvider);
    final navigator = Navigator.of(context);
    final sources = encodeAnswerSources(_sources);
    try {
      final int id;
      if (_isNew) {
        id = await dao.createCard(
          subjectId: widget.subjectId,
          title: _title.text,
          content: _content.text,
          kind: _usedLookup
              ? CardKind.lookup
              : _usedPhotos || widget.initialImagePaths.isNotEmpty
                  ? CardKind.photo
                  : CardKind.text,
          sources: sources,
        );
      } else {
        id = widget.card!.id;
        await dao.updateCard(
          id,
          title: _title.text,
          content: _content.text,
        );
        if (sources != _savedSources) await dao.setCardSources(id, sources);
      }
      await _storePhotos(id);
      // In the background: the digest is a nicety for later lessons and must
      // never hold the editor open. It skips cards that already have one.
      unawaited(digests.digest(id));
      navigator.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The pages behind the text. A photo that fails to store costs the picture,
  /// never the card the student just wrote.
  Future<void> _storePhotos(int cardId) async {
    final copies = _isNew ? widget.initialImagePaths : const <String>[];
    if (copies.isEmpty && _newPages.isEmpty) return;
    try {
      final docs = await documentsPath();
      final dir = cardPhotosDir(docs, cardId);
      final stored = [
        ...await copyPhotos(docsPath: docs, dir: dir, storedPaths: copies),
        for (final page in _newPages)
          await savePhoto(
            docsPath: docs,
            dir: dir,
            bytes: page.bytes,
            extension: page.extension,
          ),
      ];
      await ref.read(subjectsDaoProvider).addCardImages(cardId, stored);
    } catch (e, st) {
      AppLog.e(_tag, 'card $cardId: photos not stored', e, st);
    }
  }

  void _delete() {
    final card = widget.card;
    if (card == null) return;
    final deleter = ref.read(cardDeleterProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    deleteWithUndo(
      messenger: messenger,
      ref: ref,
      kind: DeletionKind.card,
      id: card.id,
      message: 'Karta smazána',
      commit: () => deleter.deleteCard(card.id),
    );
  }

  Future<void> _confirmDiscard() async {
    final navigator = Navigator.of(context);
    final discard = await showConfirmDialog(
      context,
      title: 'Zahodit změny?',
      message: 'Co jsi v kartě změnil, se neuloží.',
      confirmLabel: 'Zahodit',
      destructive: true,
    );
    if (discard) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _busy;
    final canSave = _title.text.trim().isNotEmpty && !_saving && busy == null;
    final hasGemini = ref.watch(hasGeminiKeyProvider).valueOrNull ?? false;
    final photoPaths = [
      ..._storedImages,
      if (_isNew) ...widget.initialImagePaths,
    ];

    return PopScope(
      canPop: !_dirty && busy == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy == null) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Nová karta' : 'Upravit kartu'),
          bottom: busy == null
              ? null
              : const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
          actions: [
            TextButton(
              onPressed: canSave ? _save : null,
              child: const Text('Uložit'),
            ),
            if (!_isNew)
              PopupMenuButton<_CardAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Další akce',
                onSelected: (_) => _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _CardAction.delete,
                    child: MenuRow(
                      icon: Icons.delete_outline,
                      label: 'Smazat kartu',
                      destructive: true,
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
          children: [
            TextField(
              controller: _title,
              autofocus: _isNew && widget.initialTitle == null,
              maxLength: SubjectsDao.maxCardTitleLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(
                labelText: 'Název',
                hintText: 'Třeba Babička – Božena Němcová',
              ),
              buildCounter: (_, {required currentLength, required isFocused,
                      maxLength}) =>
                  null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: busy == null ? _fromPhotos : null,
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Z fotky'),
                ),
                OutlinedButton.icon(
                  onPressed: busy == null ? _lookUp : null,
                  icon: const Icon(Icons.travel_explore, size: 18),
                  label: const Text('Dohledat'),
                ),
              ],
            ),
            if (busy != null)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(busy, style: theme.textTheme.bodySmall),
                    ),
                    TextButton(onPressed: _stop, child: const Text('Zrušit')),
                  ],
                ),
              )
            else if (!hasGemini)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Text(
                  'Přidej Gemini klíč v Nastavení — čte text z fotek a '
                  'dohledává podrobněji.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: _content,
              minLines: 10,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Obsah',
                alignLabelWithHint: true,
                hintText: 'O čem to je, postavy, pojmy, co probíráte…',
                helperText: 'Napiš, o čem to je — AI to použije při '
                    'odpovídání v hodině.',
                helperMaxLines: 2,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (photoPaths.isNotEmpty || _newPages.isNotEmpty) ...[
              const SizedBox(height: Gap.lg),
              Text('Fotky', style: theme.textTheme.labelLarge),
              const SizedBox(height: Gap.sm),
              SizedBox(
                height: 88,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final path in photoPaths)
                      _Thumb(
                        onTap: () => showStoredPhoto(context, path),
                        child: StoredPhoto(storedPath: path, width: 72, height: 88),
                      ),
                    for (final page in _newPages)
                      _Thumb(
                        onRemove: busy == null
                            ? () => setState(() => _newPages.remove(page))
                            : null,
                        child: Image.memory(
                          page.bytes,
                          width: 72,
                          height: 88,
                          fit: BoxFit.cover,
                          cacheWidth: 216,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_sources.isNotEmpty) ...[
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('Zdroje', style: theme.textTheme.labelLarge),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _sources = const []),
                    child: const Text('Odebrat'),
                  ),
                ],
              ),
              AnswerSources(sources: _sources),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, this.onTap, this.onRemove});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Gap.sm),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                tooltip: 'Odebrat fotku',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}
