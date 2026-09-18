import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/syllabus.dart';
import '../syllabus_import_screen.dart' show monthRangeLabel;
import '../../../core/spacing.dart';
import '../../../data/db/app_database.dart';
import '../subjects_providers.dart';
import 'lesson_sheet.dart';
import 'subject_badge.dart';

/// „Čeština · Babička +1" under a lesson's app bar: what the AI knows about
/// this lesson, and the way to change it mid-lesson.
class LessonContextStrip extends ConsumerWidget {
  const LessonContextStrip({super.key, required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectId = meeting.subjectId;
    if (subjectId == null) return const SizedBox.shrink();

    final subject = ref.watch(subjectProvider(subjectId)).valueOrNull;
    if (subject == null) return const SizedBox.shrink();
    final cards =
        ref.watch(pinnedCardsProvider(meeting.id)).valueOrNull ??
        const <ContextCard>[];
    final topics =
        ref.watch(subjectTopicsProvider(subjectId)).valueOrNull ??
        const <SyllabusTopic>[];
    final topic = lessonTopic(meeting, topics);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = StringBuffer(subject.name);
    if (cards.isNotEmpty) {
      label.write(' · ${cards.first.title}');
      if (cards.length > 1) label.write(' +${cards.length - 1}');
    }

    return Material(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => showLessonSheet(context, ref, meeting),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.sm + 2,
          ),
          child: Row(
            children: [
              SubjectDot(color: subjectColor(context, subject.colorIndex)),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  label.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (topics.isNotEmpty) ...[
                const SizedBox(width: Gap.sm),
                Flexible(
                  child: ActionChip(
                    avatar: Icon(
                      meeting.topicId == null
                          ? Icons.auto_awesome_outlined
                          : Icons.menu_book_outlined,
                      size: 16,
                    ),
                    label: Text(
                      topic == null ? 'Téma' : 'Téma: ${topic.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    tooltip: 'Změnit téma hodiny',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _pickTopic(context, ref, topics),
                  ),
                ),
                const SizedBox(width: Gap.sm),
              ],
              if ((meeting.rules ?? '').isNotEmpty) ...[
                Icon(Icons.rule, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: Gap.sm),
              ],
              Icon(Icons.tune, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTopic(
    BuildContext context,
    WidgetRef ref,
    List<SyllabusTopic> topics,
  ) async {
    final picked = await showModalBottomSheet<({int? id})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => TopicPickerSheet(
        topics: topics,
        selectedId: meeting.topicId,
        date: meeting.createdAt,
      ),
    );
    if (picked == null) return;
    await ref.read(subjectsDaoProvider).setMeetingTopic(meeting.id, picked.id);
  }
}

/// Pick a topic for one lesson, or „Automaticky" (by the plan's months).
/// Pops `(id: null)` for automatic, `(id: n)` for a topic.
class TopicPickerSheet extends StatelessWidget {
  const TopicPickerSheet({
    super.key,
    required this.topics,
    required this.selectedId,
    required this.date,
  });

  final List<SyllabusTopic> topics;
  final int? selectedId;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auto = currentTopics(topics, date);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
              child: Text('Téma hodiny', style: theme.textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Automaticky'),
              subtitle: Text(
                auto.isEmpty ? 'Podle tematického plánu' : auto.first.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: selectedId == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop((id: null)),
            ),
            for (final t in topics)
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(t.title),
                subtitle: switch (monthRangeLabel(t.monthFrom, t.monthTo)) {
                  final m? => Text(m),
                  null => null,
                },
                trailing: selectedId == t.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop((id: t.id)),
              ),
          ],
        ),
      ),
    );
  }
}
