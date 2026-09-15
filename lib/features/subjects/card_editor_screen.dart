import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/menu_row.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/subjects_dao.dart';
import 'subjects_providers.dart';

enum _CardAction { delete }

/// Creates a context card, or edits [card] when one is given.
///
/// A card is what the AI reads during a lesson: a book, a topic, a set of
/// terms. The content is free text on purpose — the student writes it the way
/// they think about it, and the AI copes with any shape.
class CardEditorScreen extends ConsumerStatefulWidget {
  const CardEditorScreen({super.key, required this.subjectId, this.card});

  final int subjectId;
  final ContextCard? card;

  static Route<void> route({required int subjectId, ContextCard? card}) =>
      MaterialPageRoute<void>(
        builder: (_) => CardEditorScreen(subjectId: subjectId, card: card),
      );

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  late final _title = TextEditingController(text: widget.card?.title ?? '');
  late final _content =
      TextEditingController(text: widget.card?.content ?? '');
  bool _saving = false;

  bool get _isNew => widget.card == null;

  bool get _dirty =>
      _title.text.trim() != (widget.card?.title ?? '') ||
      _content.text.trim() != (widget.card?.content ?? '');

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final dao = ref.read(subjectsDaoProvider);
    final digests = ref.read(cardDigestServiceProvider);
    final navigator = Navigator.of(context);
    try {
      final int id;
      if (_isNew) {
        id = await dao.createCard(
          subjectId: widget.subjectId,
          title: _title.text,
          content: _content.text,
        );
      } else {
        id = widget.card!.id;
        await dao.updateCard(
          id,
          title: _title.text,
          content: _content.text,
        );
      }
      // In the background: the digest is a nicety for later lessons and must
      // never hold the editor open. It skips cards that already have one.
      unawaited(digests.digest(id));
      navigator.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final card = widget.card;
    if (card == null) return;
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.delete_outline,
      title: 'Smazat kartu „${card.title}"?',
      message: 'Karta zmizí i z hodin, ve kterých byla připnutá.',
      confirmLabel: 'Smazat',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(subjectsDaoProvider).deleteCard(card.id);
    navigator.pop();
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
    final canSave = _title.text.trim().isNotEmpty && !_saving;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Nová karta' : 'Upravit kartu'),
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
              autofocus: _isNew,
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
          ],
        ),
      ),
    );
  }
}
