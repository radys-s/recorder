import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';
import '../../../core/providers.dart';
import '../../../data/db/daos/subjects_dao.dart';
import '../subjects_providers.dart';

final subjectTermsProvider = StreamProvider.family<List<SubjectTerm>, int>((
  ref,
  subjectId,
) {
  return ref.watch(subjectsDaoProvider).watchTerms(subjectId);
});

/// „Slovník předmětu" in a subject's settings: names and terms the
/// transcription should spell right, and the misheard forms it should fix.
class SubjectVocabulary extends ConsumerWidget {
  const SubjectVocabulary({super.key, required this.subjectId});

  final int subjectId;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    SubjectTerm? term,
  ]) async {
    final result = await showDialog<({String term, String heard})>(
      context: context,
      builder: (_) => _TermDialog(term: term),
    );
    if (result == null) return;
    final dao = ref.read(subjectsDaoProvider);
    final heard = result.heard.trim().isEmpty ? null : result.heard;
    try {
      if (term == null) {
        await dao.addTerm(subjectId, result.term, heard: heard);
      } else {
        await dao.updateTerm(term.id, term: result.term, heard: heard);
      }
    } on ArgumentError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Špatně slyšený tvar se musí lišit od správného.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final terms =
        ref.watch(subjectTermsProvider(subjectId)).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Slovník předmětu', style: theme.textTheme.titleSmall),
        const SizedBox(height: Gap.xs),
        Text(
          'Jména a pojmy, které má přepis psát správně. Plní se i sám, '
          'když opravíš slovo v přepisu.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.sm),
        for (final term in terms)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              term.heard == null ? Icons.translate : Icons.spellcheck,
            ),
            title: Text(
              term.heard == null ? term.term : '${term.heard} › ${term.term}',
            ),
            subtitle: Text(term.source.label),
            onTap: () => _edit(context, ref, term),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Odebrat ze slovníku',
              onPressed: () =>
                  ref.read(subjectsDaoProvider).deleteTerm(term.id),
            ),
          ),
        Wrap(
          spacing: Gap.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Přidat pojem'),
            ),
            _AliasButton(subjectId: subjectId),
          ],
        ),
      ],
    );
  }
}

/// Asks the AI how Czech speech recognition mishears this subject's foreign
/// terms, and stores the answers as corrections.
///
/// The plan's save does this on its own; the button is for a vocabulary that
/// grew afterwards, and for trying again when the first call ran into a limit.
class _AliasButton extends ConsumerStatefulWidget {
  const _AliasButton({required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<_AliasButton> createState() => _AliasButtonState();
}

class _AliasButtonState extends ConsumerState<_AliasButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final written = await ref
        .read(termAliasServiceProvider)
        .generate(widget.subjectId);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            written == 0
                ? 'Žádné nové slyšené podoby.'
                : 'Přidáno ${czechCount(written, 'slyšená podoba', 'slyšené podoby', 'slyšených podob')}.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.hearing),
      label: const Text('Doplnit slyšené podoby'),
    );
  }
}

class _TermDialog extends StatefulWidget {
  const _TermDialog({this.term});

  final SubjectTerm? term;

  @override
  State<_TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<_TermDialog> {
  late final _term = TextEditingController(text: widget.term?.term ?? '');
  late final _heard = TextEditingController(text: widget.term?.heard ?? '');

  @override
  void dispose() {
    _term.dispose();
    _heard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _term.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.term == null ? 'Nový pojem' : 'Upravit pojem'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _term,
            autofocus: true,
            maxLength: SubjectsDao.maxTermLength,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Správně'),
          ),
          TextField(
            controller: _heard,
            maxLength: SubjectsDao.maxTermLength,
            decoration: const InputDecoration(
              labelText: 'Přepis píše (nepovinné)',
              helperText: 'Třeba „prosko" — opraví se na správný tvar.',
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        FilledButton(
          onPressed: ok
              ? () =>
                    Navigator.of(context)
                        .pop((term: _term.text, heard: _heard.text))
              : null,
          child: const Text('Uložit'),
        ),
      ],
    );
  }
}
