import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/inset_group.dart';
import '../../data/db/app_database.dart';
import '../../data/db/daos/study_cards_dao.dart';
import '../../data/db/tables/study_cards_table.dart';
import '../../learning/study_flow.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../subjects/subjects_providers.dart';
import 'review_screen.dart';
import 'study_providers.dart';

/// A subject's study cards: edit, pause, delete, add by hand.
class StudyCardsScreen extends ConsumerWidget {
  const StudyCardsScreen({super.key, required this.subjectId});

  final int subjectId;

  static Route<void> route(int subjectId) =>
      MaterialPageRoute(builder: (_) => StudyCardsScreen(subjectId: subjectId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectProvider(subjectId)).valueOrNull;
    final cards = ref.watch(subjectStudyCardsProvider(subjectId));
    final now = ref.watch(studyClockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subject == null ? 'Kartičky' : 'Kartičky · ${subject.name}',
        ),
        actions: [
          IconButton(
            tooltip: 'Opakovat',
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: () =>
                Navigator.of(context)
                    .push(ReviewScreen.route(subjectId: subjectId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nová kartička'),
      ),
      body: AsyncView(
        value: cards,
        message: 'Kartičky se nepodařilo načíst.',
        onRetry: () => ref.invalidate(subjectStudyCardsProvider(subjectId)),
        builder: (all) {
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.style_outlined,
              title: 'Zatím žádné kartičky',
              message:
                  'Vzniknou samy z výpisků hodin, nebo je vytvoř z uložené '
                  'poznámky. Můžeš je přidat i ručně.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: Gap.fabClearance),
            children: [
              InsetGroup(
                label: czechCount(
                  all.length,
                  'kartička',
                  'kartičky',
                  'kartiček',
                ),
                dividerIndent: Gap.lg,
                children: [
                  for (final c in all)
                    ListRow(
                      title: c.front,
                      subtitle: c.back,
                      status: c.suspended ? 'Pozastaveno' : _due(c, now),
                      chevron: false,
                      leadingSlot: 0,
                      onTap: () => _edit(context, ref, c),
                      onLongPress: () => _menu(context, ref, c),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _due(StudyCard c, DateTime now) {
    if (c.dueAt.isBefore(endOfStudyDay(now))) return 'Dnes';
    return 'Další ${DateFormat('d. M.', 'cs').format(c.dueAt)}';
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await _cardDialog(context, title: 'Nová kartička');
    if (result == null) return;
    final added = await ref.read(studyCardsDaoProvider).addCards(subjectId, [
      StudyItem(result.$1, result.$2, StudySource.manual),
    ], now: ref.read(studyClockProvider)());
    if (added == 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takovou otázku už předmět má.')),
      );
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, StudyCard c) async {
    final result = await _cardDialog(
      context,
      title: 'Upravit kartičku',
      front: c.front,
      back: c.back,
    );
    if (result == null) return;
    try {
      await ref
          .read(studyCardsDaoProvider)
          .updateCard(c.id, front: result.$1, back: result.$2);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kartičku se nepodařilo uložit. Nemá předmět už '
            'stejnou otázku?',
          ),
        ),
      );
    }
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, StudyCard c) async {
    // The source lesson, if the card still has one: its date for the
    // provenance line and the way back to the výpisky.
    final lessonId = c.meetingId;
    final lesson = lessonId == null
        ? null
        : await ref
              .read(appDatabaseProvider)
              .meetingsDao
              .watchMeetingByIdOnce(lessonId);
    if (!context.mounted) return;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  studyCardProvenance(c, lessonDate: lesson?.createdAt),
                  style: muted,
                ),
              ),
            ),
            if (lesson != null)
              ListTile(
                leading: const Icon(Icons.north_east_rounded),
                title: const Text('Otevřít zdrojovou hodinu'),
                onTap: () => Navigator.pop(context, 'lesson'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Upravit'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: Icon(
                c.suspended ? Icons.play_arrow_outlined : Icons.pause_outlined,
              ),
              title: Text(c.suspended ? 'Obnovit opakování' : 'Pozastavit'),
              onTap: () => Navigator.pop(context, 'suspend'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Smazat'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final dao = ref.read(studyCardsDaoProvider);
    switch (action) {
      case 'edit':
        await _edit(context, ref, c);
      case 'lesson':
        await Navigator.of(context)
            .push(MeetingDetailScreen.route(c.meetingId!, initialTab: 1));
      case 'suspend':
        await dao.setSuspended(c.id, !c.suspended);
      case 'delete':
        final messenger = ScaffoldMessenger.of(context);
        await dao.deleteCard(c.id);
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Kartička smazána'),
            action: SnackBarAction(
              label: 'Vrátit',
              onPressed: () => dao.restore(c),
            ),
          ),
        );
    }
  }
}

/// Question and answer fields; null when cancelled.
Future<(String, String)?> _cardDialog(
  BuildContext context, {
  required String title,
  String front = '',
  String back = '',
}) {
  final f = TextEditingController(text: front);
  final b = TextEditingController(text: back);
  return showDialog<(String, String)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final ok = f.text.trim().isNotEmpty && b.text.trim().isNotEmpty;
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: f,
                  autofocus: front.isEmpty,
                  maxLength: StudyCardsDao.maxFrontLength,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Otázka'),
                ),
                TextField(
                  controller: b,
                  maxLength: StudyCardsDao.maxBackLength,
                  minLines: 2,
                  maxLines: 8,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Odpověď'),
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
              onPressed: ok
                  ? () => Navigator.pop(context, (f.text.trim(), b.text.trim()))
                  : null,
              child: const Text('Uložit'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() {
    f.dispose();
    b.dispose();
  });
}
