import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';
import '../../subjects/subjects_providers.dart';
import '../meeting_detail_providers.dart';
import '../transcript_fix.dart';

/// Long-press sheet on a transcript row: pick the misheard words, type what
/// was said, and the fix goes through the whole lesson (and, remembered, every
/// later lesson of the subject). Shows what was heard first when the row was
/// already corrected, with a way back.
Future<void> showWordFixSheet(
  BuildContext context, {
  required int meetingId,
  required String text,
  String? original,
  Future<void> Function()? onRestore,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => WordFixSheet(
      meetingId: meetingId,
      text: text,
      original: original,
      onRestore: onRestore,
    ),
  );
}

class WordFixSheet extends ConsumerStatefulWidget {
  const WordFixSheet({
    super.key,
    required this.meetingId,
    required this.text,
    this.original,
    this.onRestore,
  });

  final int meetingId;
  final String text;
  final String? original;
  final Future<void> Function()? onRestore;

  @override
  ConsumerState<WordFixSheet> createState() => _WordFixSheetState();
}

class _WordFixSheetState extends ConsumerState<WordFixSheet> {
  late final _words = wordsOf(widget.text);
  final _fix = TextEditingController();
  int? _start;
  int? _end;
  bool _remember = true;
  bool _busy = false;

  @override
  void dispose() {
    _fix.dispose();
    super.dispose();
  }

  String get _heard => _start == null
      ? ''
      : widget.text.substring(_words[_start!].start, _words[_end!].end);

  void _tap(int i) {
    setState(() {
      final start = _start;
      final end = _end;
      if (start == null || end == null || (i >= start && i <= end)) {
        _start = _end = i;
      } else if (i == start - 1) {
        _start = i;
      } else if (i == end + 1) {
        _end = i;
      } else {
        _start = _end = i;
      }
      _fix.text = _heard;
      _fix.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _fix.text.length,
      );
    });
  }

  bool get _canSave {
    final term = _fix.text.trim();
    return !_busy && _start != null && term.isNotEmpty && term != _heard;
  }

  Future<void> _save({required bool hasSubject}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final changed = await fixWordInMeeting(
      ref.read(appDatabaseProvider),
      meetingId: widget.meetingId,
      heard: _heard,
      term: _fix.text,
      remember: hasSubject && _remember,
    );
    final edited = ref.read(transcriptEditedAtProvider.notifier);
    edited.state = {...edited.state, widget.meetingId: DateTime.now()};
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            changed <= 1
                ? 'Opraveno.'
                : 'Opraveno na $changed místech v přepisu.',
          ),
        ),
      );
  }

  Future<void> _restore() async {
    final navigator = Navigator.of(context);
    await widget.onRestore?.call();
    final edited = ref.read(transcriptEditedAtProvider.notifier);
    edited.state = {...edited.state, widget.meetingId: DateTime.now()};
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subjectId = ref
        .watch(meetingProvider(widget.meetingId))
        .valueOrNull
        ?.subjectId;
    final subjectName = subjectId == null
        ? null
        : ref.watch(subjectProvider(subjectId)).valueOrNull?.name;
    final original = widget.original;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Opravit slovo', style: theme.textTheme.titleLarge),
              const SizedBox(height: Gap.xs),
              Text(
                'Klepni na špatně slyšené slovo (nebo víc slov vedle sebe) '
                'a napiš, co zaznělo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (var i = 0; i < _words.length; i++)
                    ChoiceChip(
                      label: Text(_words[i].word),
                      selected: _start != null && i >= _start! && i <= _end!,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: _busy ? null : (_) => _tap(i),
                    ),
                ],
              ),
              if (_start != null) ...[
                const SizedBox(height: Gap.lg),
                TextField(
                  controller: _fix,
                  autofocus: true,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.none,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Správně',
                    helperText: 'Místo „$_heard" v celé hodině',
                  ),
                ),
                if (subjectName != null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _remember,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _remember = v ?? true),
                    title: Text('Zapamatovat pro předmět $subjectName'),
                    subtitle: const Text('Příště se opraví samo.'),
                  ),
                const SizedBox(height: Gap.sm),
                FilledButton.icon(
                  onPressed: _canSave
                      ? () => _save(hasSubject: subjectName != null)
                      : null,
                  icon: const Icon(Icons.spellcheck),
                  label: const Text('Opravit'),
                ),
              ],
              if (original != null && original != widget.text) ...[
                const SizedBox(height: Gap.xl),
                Text('Původně slyšeno', style: theme.textTheme.titleSmall),
                const SizedBox(height: Gap.xs),
                Text(
                  original,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (widget.onRestore != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _restore,
                      icon: const Icon(Icons.undo),
                      label: const Text('Vrátit původní'),
                    ),
                  ),
              ],
              const SizedBox(height: Gap.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.text));
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopírovat text'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
