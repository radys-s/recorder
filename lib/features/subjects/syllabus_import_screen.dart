import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_route.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../ai/course_profile.dart';
import '../../ai/gemini_provider.dart';
import '../../ai/photo_text_service.dart' show geminiFailureText;
import '../../ai/syllabus.dart';
import '../../ai/syllabus_import_service.dart';
import '../../core/photo_picker.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/db/app_database.dart';
import '../../data/db/tables/syllabus_topics_table.dart';
import '../meeting_detail/widgets/answer_sources.dart';
import 'subjects_providers.dart';

enum _PhotoSource { gallery, camera }

/// Czech month names in the nominative, January first.
const kMonthNames = [
  'leden',
  'únor',
  'březen',
  'duben',
  'květen',
  'červen',
  'červenec',
  'srpen',
  'září',
  'říjen',
  'listopad',
  'prosinec',
];

/// „září", „září–říjen", or null when the plan gives no time.
String? monthRangeLabel(int? from, int? to) {
  if (from == null) return null;
  final start = kMonthNames[from - 1];
  if (to == null || to == from) return start;
  return '$start–${kMonthNames[to - 1]}';
}

/// Starts an import of the subject's thematic plan from pasted text, photos
/// or an AI estimate, and opens the review. Nothing is saved before „Uložit".
Future<void> importSyllabusFlow(
  BuildContext context,
  WidgetRef ref,
  Subject subject,
  SyllabusSource source,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  switch (source) {
    case SyllabusSource.pasted:
      final text = await showDialog<String>(
        context: context,
        builder: (_) => const _PasteDialog(),
      );
      if (text == null) return;
      await navigator.push(
        SyllabusImportScreen.route(subject: subject, text: text),
      );
    case SyllabusSource.photo || SyllabusSource.pdf:
      ref.invalidate(hasVisionKeyProvider);
      if (!await ref.read(hasVisionKeyProvider.future)) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Plán z fotky čte Gemini nebo Mistral. Přidej klíč v '
                'Nastavení.',
              ),
            ),
          );
        return;
      }
      if (!context.mounted) return;
      final pick = await showModalBottomSheet<_PhotoSource>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Vybrat obrázky'),
                subtitle: const Text('Screenshoty nebo fotky stránek plánu.'),
                onTap: () => Navigator.pop(context, _PhotoSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Vyfotit plán'),
                onTap: () => Navigator.pop(context, _PhotoSource.camera),
              ),
            ],
          ),
        ),
      );
      if (pick == null) return;
      final picker = ref.read(photoPickerProvider);
      final List<PickedPhoto> photos;
      try {
        photos = pick == _PhotoSource.gallery
            ? await picker.pickPages()
            : [?await picker.takePhoto()];
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Obrázek se nepodařilo otevřít.')),
        );
        return;
      }
      if (photos.isEmpty) return;
      await navigator.push(
        SyllabusImportScreen.route(subject: subject, photos: photos),
      );
    case SyllabusSource.ai:
      await navigator.push(SyllabusImportScreen.route(subject: subject));
  }
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = _controller.text.trim().isEmpty;
    return AlertDialog(
      title: const Text('Vložit tematický plán'),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 6,
          maxLines: 14,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Zkopíruj plán z webu školy, ŠVP nebo e-mailu.',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušit'),
        ),
        FilledButton(
          onPressed: empty
              ? null
              : () => Navigator.pop(context, _controller.text),
          child: const Text('Přečíst'),
        ),
      ],
    );
  }
}

/// Reads or estimates a plan and lets the student fix it before it replaces
/// the subject's current one.
class SyllabusImportScreen extends ConsumerStatefulWidget {
  const SyllabusImportScreen({
    super.key,
    required this.subject,
    this.text,
    this.photos,
  });

  final Subject subject;

  /// Pasted plan; with neither this nor [photos] the plan is estimated.
  final String? text;
  final List<PickedPhoto>? photos;

  static Route<void> route({
    required Subject subject,
    String? text,
    List<PickedPhoto>? photos,
  }) => AppRoute(
    builder: (_) =>
        SyllabusImportScreen(subject: subject, text: text, photos: photos),
  );

  SyllabusSource get source => text != null
      ? SyllabusSource.pasted
      : photos != null
      ? SyllabusSource.photo
      : SyllabusSource.ai;

  @override
  ConsumerState<SyllabusImportScreen> createState() =>
      _SyllabusImportScreenState();
}

class _SyllabusImportScreenState extends ConsumerState<SyllabusImportScreen> {
  SyllabusImport? _result;
  List<SyllabusTopicDraft> _topics = const [];
  int _existing = 0;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      final prefs = await db.preferencesDao.current();
      final subject =
          await db.subjectsDao.subject(widget.subject.id) ?? widget.subject;
      _existing = (await db.subjectsDao.topics(subject.id)).length;
      final course = courseLine(subject, prefs);
      final service = ref.read(syllabusImportServiceProvider);
      final result = switch (widget.source) {
        SyllabusSource.pasted => await service.fromText(
          widget.text!,
          course: course,
        ),
        SyllabusSource.photo || SyllabusSource.pdf => await service.fromImages([
          for (final p in widget.photos!)
            LlmImage(p.bytes, mimeType: p.mimeType),
        ], course: course),
        SyllabusSource.ai => await service.estimate(course: course),
      };
      if (!mounted) return;
      setState(() {
        _result = result;
        _topics = [...result.topics];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = geminiFailureText(e));
    }
  }

  Future<void> _edit(int index) async {
    final edited = await showDialog<SyllabusTopicDraft>(
      context: context,
      builder: (_) => TopicEditDialog(topic: _topics[index]),
    );
    if (edited == null || !mounted) return;
    setState(() => _topics = [..._topics]..[index] = edited);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(subjectsDaoProvider)
          .replaceTopics(widget.subject.id, _topics, widget.source);
      // The plan is where a subject's foreign terms arrive, so this is the
      // moment to learn how Czech speech recognition mishears them. Unawaited:
      // one AI call must never hold up saving what the student just reviewed.
      unawaited(ref.read(termAliasServiceProvider).generate(widget.subject.id));
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Plán uložen: ${topicCount(_topics.length)}.'),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Plán se nepodařilo uložit.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Tematický plán')),
      body: _error != null
          ? EmptyState(
              icon: Icons.event_note_outlined,
              title: 'Plán se nepodařilo přečíst',
              message: _error!,
              action: FilledButton.tonal(
                style: tonalButtonStyle(context),
                onPressed: _read,
                child: const Text('Zkusit znovu'),
              ),
            )
          : result == null
          ? _Reading(estimate: widget.source == SyllabusSource.ai)
          : _buildList(result),
      bottomNavigationBar: result == null || _error != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(Gap.lg),
              child: FilledButton(
                onPressed: _topics.isEmpty || _saving ? null : _save,
                child: Text(
                  _topics.isEmpty
                      ? 'Žádná témata'
                      : 'Uložit ${topicCount(_topics.length)}',
                ),
              ),
            ),
    );
  }

  Widget _buildList(SyllabusImport result) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.estimated) ...[
            Card(
              color: scheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 18,
                          color: scheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: Gap.sm),
                        Text(
                          'Odhad AI',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Tvoje škola může učit jinak. Až budeš mít skutečný '
                      'plán, nahraď ho.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                    if (result.sources.isNotEmpty) ...[
                      const SizedBox(height: Gap.sm),
                      AnswerSources(sources: result.sources),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
          Text(
            [
              'Klepnutím téma upravíš, podržením přesuneš.',
              if (_existing > 0)
                'Uložením nahradíš současný plán (${topicCount(_existing)}).',
            ].join(' '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return ReorderableListView.builder(
      header: header,
      padding: const EdgeInsets.only(bottom: Gap.xl),
      itemCount: _topics.length,
      onReorderItem: (from, to) => setState(() {
        final list = [..._topics];
        final item = list.removeAt(from);
        list.insert(to, item);
        _topics = list;
      }),
      itemBuilder: (context, i) {
        final t = _topics[i];
        final months = monthRangeLabel(t.monthFrom, t.monthTo);
        return ListTile(
          key: ObjectKey(t),
          leading: CircleAvatar(
            radius: 14,
            child: Text('${i + 1}', style: theme.textTheme.labelSmall),
          ),
          title: Text(t.title),
          subtitle: Text(
            [
              ?months,
              if (t.terms.isNotEmpty) t.terms.take(6).join(', '),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _edit(i),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Odebrat téma',
            onPressed: () =>
                setState(() => _topics = [..._topics]..removeAt(i)),
          ),
        );
      },
    );
  }
}

/// Edits one topic's title, terms and months.
class TopicEditDialog extends StatefulWidget {
  const TopicEditDialog({super.key, required this.topic});

  final SyllabusTopicDraft topic;

  @override
  State<TopicEditDialog> createState() => _TopicEditDialogState();
}

class _TopicEditDialogState extends State<TopicEditDialog> {
  late final _title = TextEditingController(text: widget.topic.title);
  late final _terms = TextEditingController(
    text: widget.topic.terms.join(', '),
  );
  late int? _from = widget.topic.monthFrom;
  late int? _to = widget.topic.monthTo;

  @override
  void dispose() {
    _title.dispose();
    _terms.dispose();
    super.dispose();
  }

  /// School-year order, September first.
  static const _order = [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8];

  Widget _month(String label, int? value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        for (final m in _order)
          DropdownMenuItem(value: m, child: Text(kMonthNames[m - 1])),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _title.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Téma'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              maxLength: kSyllabusTitleMaxChars,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Název'),
            ),
            TextField(
              controller: _terms,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Pojmy',
                helperText: 'Oddělené čárkou. Pomáhají přepisu hodiny.',
              ),
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: _month('Od', _from, (v) => setState(() => _from = v)),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _month('Do', _to, (v) => setState(() => _to = v)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušit'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  SyllabusTopicDraft(
                    title: _title.text.trim(),
                    description: widget.topic.description,
                    terms: parseTerms(_terms.text),
                    monthFrom: _from ?? _to,
                    monthTo: _to ?? _from,
                  ),
                )
              : null,
          child: const Text('Uložit'),
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.estimate});

  final bool estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Gap.lg),
            Text(
              estimate ? 'Odhaduji plán…' : 'Čtu plán…',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              estimate
                  ? 'AI hledá, co se v tomto předmětu a ročníku učí.'
                  : 'AI hledá témata, pojmy a měsíce.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `1 téma`, `3 témata`, `5 témat`.
String topicCount(int n) => switch (n) {
  1 => '1 téma',
  >= 2 && <= 4 => '$n témata',
  _ => '$n témat',
};
