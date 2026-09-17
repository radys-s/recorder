import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/syllabus.dart';
import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/tables/syllabus_topics_table.dart';
import '../subjects_providers.dart';
import '../syllabus_import_screen.dart';

/// The draft form of a stored topic, for the edit dialog.
SyllabusTopicDraft draftOf(SyllabusTopic t) => SyllabusTopicDraft(
  title: t.title,
  description: t.description,
  terms: parseTerms(t.terms),
  monthFrom: t.monthFrom,
  monthTo: t.monthTo,
);

String syllabusSourceLabel(SyllabusSource source) => switch (source) {
  SyllabusSource.pasted => 'z vloženého textu',
  SyllabusSource.photo => 'z fotky',
  SyllabusSource.pdf => 'z PDF',
  SyllabusSource.ai => 'odhad AI',
};

/// „Tematický plán" in a subject's settings: the course's full name and level,
/// and the topics the lessons are matched against.
class SubjectSyllabus extends ConsumerStatefulWidget {
  const SubjectSyllabus({super.key, required this.subject, this.now});

  final Subject subject;

  /// Injectable for tests; the current topic depends on the date.
  final DateTime? now;

  @override
  ConsumerState<SubjectSyllabus> createState() => _SubjectSyllabusState();
}

class _SubjectSyllabusState extends ConsumerState<SubjectSyllabus> {
  late final _fullName = TextEditingController(
    text: widget.subject.fullName ?? '',
  );
  late final _level = TextEditingController(
    text: widget.subject.levelOverride ?? '',
  );

  bool get _changed =>
      _fullName.text.trim() != (widget.subject.fullName ?? '') ||
      _level.text.trim() != (widget.subject.levelOverride ?? '');

  @override
  void dispose() {
    _fullName.dispose();
    _level.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    await ref
        .read(subjectsDaoProvider)
        .setSubjectProfile(
          widget.subject.id,
          fullName: _fullName.text,
          levelOverride: _level.text,
        );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Předmět uložen.')));
  }

  Future<void> _edit(SyllabusTopic topic) async {
    final edited = await showDialog<SyllabusTopicDraft>(
      context: context,
      builder: (_) => TopicEditDialog(topic: draftOf(topic)),
    );
    if (edited == null) return;
    await ref.read(subjectsDaoProvider).updateTopic(topic.id, edited);
  }

  Future<void> _import(SyllabusSource source) async {
    // Save a typed name first, so the estimate is for the right course.
    if (_changed) await _saveProfile();
    if (!mounted) return;
    final subject =
        await ref.read(subjectsDaoProvider).subject(widget.subject.id) ??
        widget.subject;
    if (!mounted) return;
    await importSyllabusFlow(context, ref, subject, source);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topics =
        ref.watch(subjectTopicsProvider(widget.subject.id)).valueOrNull ??
        const <SyllabusTopic>[];
    final current = {
      for (final t in currentTopics(topics, widget.now ?? DateTime.now())) t.id,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tematický plán', style: theme.textTheme.titleSmall),
        const SizedBox(height: Gap.xs),
        Text(
          'Podle plánu AI ví, co se právě probírá, a lépe rozumí pojmům '
          'v hodině.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.sm),
        TextField(
          controller: _fullName,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Celý název předmětu',
            hintText: 'Třeba: Počítačové sítě',
          ),
        ),
        const SizedBox(height: Gap.sm),
        TextField(
          controller: _level,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Ročník nebo úroveň (nepovinné)',
            hintText: 'Jen když se liší od ročníku v Nastavení',
          ),
        ),
        if (_changed) ...[
          const SizedBox(height: Gap.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _saveProfile,
              child: const Text('Uložit'),
            ),
          ),
        ],
        const SizedBox(height: Gap.md),
        if (topics.isNotEmpty)
          Text(
            '${topicCount(topics.length)} · '
            '${syllabusSourceLabel(topics.first.source)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        for (final t in topics)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              current.contains(t.id)
                  ? Icons.play_circle_fill
                  : Icons.circle_outlined,
              size: 20,
              color: current.contains(t.id) ? scheme.primary : scheme.outline,
            ),
            title: Text(
              t.title,
              style: current.contains(t.id)
                  ? TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    )
                  : null,
            ),
            subtitle: switch (monthRangeLabel(t.monthFrom, t.monthTo)) {
              final m? => Text(current.contains(t.id) ? '$m · teď' : m),
              null => current.contains(t.id) ? const Text('teď') : null,
            },
            onTap: () => _edit(t),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Odebrat téma',
              onPressed: () => ref.read(subjectsDaoProvider).deleteTopic(t.id),
            ),
          ),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () => _import(SyllabusSource.pasted),
              icon: const Icon(Icons.content_paste),
              label: const Text('Vložit text'),
            ),
            OutlinedButton.icon(
              onPressed: () => _import(SyllabusSource.photo),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Z fotky'),
            ),
            OutlinedButton.icon(
              onPressed: () => _import(SyllabusSource.ai),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Odhadnout AI'),
            ),
          ],
        ),
      ],
    );
  }
}
