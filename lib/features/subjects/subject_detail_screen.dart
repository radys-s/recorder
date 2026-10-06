import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/formatting.dart';
import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/inset_group.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/study_cards_dao.dart';
import '../../data/db/daos/subjects_dao.dart';
import '../../learning/study_flow.dart';
import '../study/study_providers.dart';
import '../../stt/transcript_sanitizer.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../meetings_list/meeting_actions.dart';
import '../notes_library/notes_library_providers.dart';
import 'card_editor_screen.dart';
import 'subject_actions.dart';
import 'subjects_providers.dart';
import 'timetable.dart';
import 'timetable_import_screen.dart';
import 'widgets/timetable_slot_dialog.dart';
import 'widgets/subject_overview.dart';
import 'widgets/subject_syllabus.dart';
import 'widgets/subject_vocabulary.dart';
import '../../core/pending_deletions.dart';

/// One subject: its cards, its recorded lessons, and its settings.
class SubjectDetailScreen extends ConsumerStatefulWidget {
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    this.initialTab = 0,
  });

  final int subjectId;

  /// 0 Karty, 1 Hodiny, 2 Přehled, 3 Nastavení.
  final int initialTab;

  static Route<void> route(int subjectId, {int initialTab = 0}) =>
      MaterialPageRoute<void>(
        builder: (_) =>
            SubjectDetailScreen(subjectId: subjectId, initialTab: initialTab),
      );

  @override
  ConsumerState<SubjectDetailScreen> createState() =>
      _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab,
  )..addListener(_onTab);

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(subjectProvider(widget.subjectId));
    final subject = value.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: subject == null
            ? const Text('Předmět')
            : Row(
                children: [
                  SubjectDot(
                    color: subjectColor(context, subject.colorIndex),
                    size: 12,
                  ),
                  const SizedBox(width: Gap.sm),
                  Flexible(
                    child: Text(subject.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Karty'),
            Tab(text: 'Hodiny'),
            Tab(text: 'Přehled'),
            Tab(text: 'Nastavení'),
          ],
        ),
      ),
      floatingActionButton: subject != null && _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context)
                      .push(CardEditorScreen.route(subjectId: subject.id)),
              icon: const Icon(Icons.add),
              label: const Text('Nová karta'),
            )
          : null,
      body: AsyncView(
        value: value,
        message: 'Předmět se nepodařilo načíst.',
        onRetry: () => ref.invalidate(subjectProvider(widget.subjectId)),
        builder: (subject) => subject == null
            ? const EmptyState(
                icon: Icons.school_outlined,
                title: 'Předmět už neexistuje',
              )
            : TabBarView(
                controller: _tabs,
                children: [
                  _CardsTab(subjectId: subject.id),
                  _LessonsTab(subjectId: subject.id),
                  SubjectOverview(
                    subjectId: subject.id,
                    onOpenSettings: () => _tabs.animateTo(3),
                  ),
                  _SettingsTab(key: ValueKey(subject.id), subject: subject),
                ],
              ),
      ),
    );
  }
}

// ------------------------------------------------------------------ cards

class _CardsTab extends ConsumerStatefulWidget {
  const _CardsTab({required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<_CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends ConsumerState<_CardsTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = ref.watch(pendingIdsProvider(DeletionKind.card));
    final cards = ref
        .watch(subjectCardsProvider(widget.subjectId))
        .whenData(
          (all) => [
            for (final c in all)
              if (!hidden.contains(c.id)) c,
          ],
        );

    return AsyncView(
      value: cards,
      message: 'Karty se nepodařilo načíst.',
      onRetry: () => ref.invalidate(subjectCardsProvider(widget.subjectId)),
      builder: (all) {
        if (all.isEmpty) {
          return const EmptyState(
            icon: Icons.style_outlined,
            title: 'Zatím žádné karty',
            message:
                'Karta je kontext pro AI: kniha, úryvek, téma nebo '
                'pojmy. Když ji připneš k hodině, AI podle ní odpovídá.',
          );
        }

        final words = normalizeForArtifactMatch(_search.text)
            .split(' ')
            .where((w) => w.isNotEmpty)
            .toList();
        final visible = [
          for (final card in all)
            if (words.every(
              normalizeForArtifactMatch('${card.title}\n${card.content}')
                  .contains,
            ))
              card,
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.lg,
            Gap.md,
            Gap.lg,
            Gap.fabClearance,
          ),
          children: [
            if (all.length > 3) ...[
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Hledat v kartách',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: Gap.md),
            ],
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: Gap.xl),
                child: Center(child: Text('Nic nenalezeno')),
              ),
            for (final card in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: _CardTile(card: card),
              ),
          ],
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card});

  final ContextCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = notePreview(card.content);

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(CardEditorScreen.route(subjectId: card.subjectId, card: card)),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(Gap.md),
                ),
                child: Icon(
                  Icons.style_outlined,
                  size: 19,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      preview.isEmpty ? 'Bez obsahu' : preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: preview.isEmpty ? FontStyle.italic : null,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Upraveno ${formatMeetingDate(card.updatedAt)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- lessons

class _LessonsTab extends ConsumerWidget {
  const _LessonsTab({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pendingIdsProvider(DeletionKind.meeting));
    final lessons = ref
        .watch(subjectLessonsProvider(subjectId))
        .whenData(
          (all) => [
            for (final m in all)
              if (!hidden.contains(m.id)) m,
          ],
        );

    return AsyncView(
      value: lessons,
      message: 'Hodiny se nepodařilo načíst.',
      onRetry: () => ref.invalidate(subjectLessonsProvider(subjectId)),
      builder: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.mic_none_outlined,
            title: 'Zatím žádné hodiny',
            message:
                'Když při nahrávání vybereš tento předmět, hodina se '
                'objeví tady.',
          );
        }
        final withNotes =
            ref.watch(meetingIdsWithNotesProvider).valueOrNull ?? const <int>{};
        final perLesson =
            ref.watch(subjectLessonStudyProvider(subjectId)).valueOrNull ??
            const <int, StudyStats>{};
        return ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
          children: [
            InsetGroup(
              label: 'Hodiny a látka',
              horizontalInset: 0,
              dividerIndent: ListRow.textIndent + 28,
              children: [
                for (final meeting in list)
                  _lessonRow(
                    context,
                    meeting,
                    hasNotes: withNotes.contains(meeting.id),
                    stats: perLesson[meeting.id],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// One lesson with what it holds for learning. A lesson with výpisky opens
  /// on them, because that is where the way on to the cards starts.
  Widget _lessonRow(
    BuildContext context,
    Meeting meeting, {
    required bool hasNotes,
    required StudyStats? stats,
  }) {
    final named = !isDefaultMeetingTitle(meeting.title);
    final status = lessonStudyLine(
      hasNotes: hasNotes,
      cards: stats?.total ?? 0,
      due: stats?.due ?? 0,
    );
    return ListRow(
      leadingSlot: 52,
      leading: GradientIconTile(
        icon: hasNotes ? Icons.description_outlined : Icons.mic_none_outlined,
      ),
      title: named ? meeting.title : formatMeetingDate(meeting.createdAt),
      subtitle: named
          ? '${formatMeetingDate(meeting.createdAt)} · $status'
          : status,
      onTap: () => Navigator.of(context).push(
        MeetingDetailScreen.route(meeting.id, initialTab: hasNotes ? 1 : 0),
      ),
    );
  }
}

// --------------------------------------------------------------- settings

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({super.key, required this.subject});

  final Subject subject;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late final _rules = TextEditingController(text: widget.subject.rules ?? '');

  bool get _rulesChanged => _rules.text.trim() != (widget.subject.rules ?? '');

  @override
  void dispose() {
    _rules.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    await ref
        .read(subjectsDaoProvider)
        .setSubjectRules(widget.subject.id, _rules.text);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Pravidla uložena.')));
  }

  Future<void> _addSlot() async {
    final slot = await showTimetableSlotDialog(context);
    if (slot == null) return;
    await ref
        .read(subjectsDaoProvider)
        .addSlot(
          subjectId: widget.subject.id,
          weekday: slot.weekday,
          startMinute: slot.startMinute,
          endMinute: slot.endMinute,
        );
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final deleted = await confirmAndDeleteSubject(context, ref, widget.subject);
    if (deleted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subject = widget.subject;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        Text('Pravidla pro AI', style: theme.textTheme.titleSmall),
        const SizedBox(height: Gap.sm),
        TextField(
          controller: _rules,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Třeba: odpovídej jednou větou, používej odborné pojmy',
            helperText:
                'Platí pro všechny hodiny tohoto předmětu. Pravidla '
                'napsaná v hodině mají přednost.',
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: Gap.sm),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            style: tonalButtonStyle(context),
            onPressed: _rulesChanged ? _saveRules : null,
            child: const Text('Uložit pravidla'),
          ),
        ),
        const SizedBox(height: Gap.xl),
        Text('Rozvrh', style: theme.textTheme.titleSmall),
        const SizedBox(height: Gap.xs),
        Text(
          'Když nahrávání začne v čase hodiny, předmět se vybere sám.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.sm),
        for (final slot
            in ref.watch(subjectSlotsProvider(subject.id)).valueOrNull ??
                const <TimetableSlot>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(formatSlot(slot)),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Odebrat hodinu',
              onPressed: () =>
                  ref.read(subjectsDaoProvider).deleteSlot(slot.id),
            ),
          ),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            OutlinedButton.icon(
              onPressed: _addSlot,
              icon: const Icon(Icons.add),
              label: const Text('Přidat hodinu'),
            ),
            OutlinedButton.icon(
              onPressed: () => importTimetableFlow(context, ref),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Ze screenshotu'),
            ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        SubjectSyllabus(subject: subject),
        const SizedBox(height: Gap.xl),
        SubjectVocabulary(subjectId: subject.id),
        const SizedBox(height: Gap.xl),
        Text('Barva', style: theme.textTheme.titleSmall),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: [
            for (var i = 0; i < SubjectsDao.paletteSize; i++)
              Semantics(
                button: true,
                selected: i == subject.colorIndex,
                label: 'Barva ${i + 1}',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => ref
                      .read(subjectsDaoProvider)
                      .setSubjectColor(subject.id, i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: subjectColor(context, i),
                      shape: BoxShape.circle,
                      border: i == subject.colorIndex
                          ? Border.all(color: scheme.onSurface, width: 3)
                          : null,
                    ),
                    child: i == subject.colorIndex
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.drive_file_rename_outline),
          title: const Text('Přejmenovat předmět'),
          onTap: () => renameSubjectFlow(context, ref, subject),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline, color: scheme.error),
          title: Text('Smazat předmět', style: TextStyle(color: scheme.error)),
          onTap: _delete,
        ),
      ],
    );
  }
}
