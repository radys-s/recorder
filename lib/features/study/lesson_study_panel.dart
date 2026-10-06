import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/inset_group.dart';
import '../legal/ai_disclaimer.dart';
import '../meeting_detail/meeting_detail_providers.dart';
import '../subjects/subjects_providers.dart';
import 'exam_prep_screen.dart';
import 'review_screen.dart';
import 'study_cards_screen.dart';
import 'study_providers.dart';

/// „Učení" under a lesson's výpisky: the way on from notes to learning.
///
/// Cards are made for this one lesson, on the student's tap — never for
/// every lesson at once. What the model wrote is a study aid drawn from the
/// výpisky, and the panel says so.
class LessonStudyPanel extends ConsumerStatefulWidget {
  const LessonStudyPanel({
    super.key,
    required this.meetingId,
    required this.subjectId,
  });

  final int meetingId;
  final int subjectId;

  @override
  ConsumerState<LessonStudyPanel> createState() => _LessonStudyPanelState();
}

class _LessonStudyPanelState extends ConsumerState<LessonStudyPanel> {
  var _busy = false;

  Future<void> _makeCards() async {
    if (_busy) return;
    setState(() => _busy = true);
    final int added;
    try {
      // Waits for the stream's first value: nothing here watches the notes.
      final note = await ref.read(
        meetingNotesProvider(widget.meetingId).future,
      );
      final content = note?.content?.trim();
      if (content == null || content.isEmpty) {
        if (!mounted) return;
        setState(() => _busy = false);
        _say('Z této hodiny zatím nejsou výpisky.');
        return;
      }
      added = await ref
          .read(studyCardGeneratorProvider)
          .fromLessonNotes(widget.meetingId, content);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _say('Kartičky se nepodařilo vytvořit.');
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _say(
      added > 0
          ? 'Přidáno: ${czechCount(added, 'kartička', 'kartičky', 'kartiček')}. '
                'Zkontroluj je, text psala AI.'
          : 'Nové kartičky nevznikly. Buď už existují, nebo se model '
                'neozval. Zkus to za chvíli.',
    );
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final stats = ref
        .watch(lessonStudyStatsProvider(widget.meetingId))
        .valueOrNull;
    final total = stats?.total ?? 0;
    final due = stats?.due ?? 0;
    final nav = Navigator.of(context);

    final summary = total == 0
        ? 'Z těchto výpisků zatím nejsou kartičky.'
        : '${czechCount(total, 'kartička', 'kartičky', 'kartiček')} z této hodiny'
              ' · dnes ${due == 0 ? 'nic' : due}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsetGroup(
          label: 'Učení',
          horizontalInset: 0,
          dividerIndent: ListRow.textIndent + 28,
          children: [
            if (total == 0)
              ListRow(
                leadingSlot: 52,
                leading: _busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const GradientIconTile(icon: Icons.style_outlined),
                title: _busy ? 'Vytvářím kartičky…' : 'Vytvořit kartičky',
                subtitle: summary,
                chevron: !_busy,
                onTap: _busy ? null : _makeCards,
              )
            else
              ListRow(
                leadingSlot: 52,
                leading: const GradientIconTile(icon: Icons.replay_rounded),
                title: due > 0 ? 'Opakovat z hodiny' : 'Dnes nic nečeká',
                subtitle: summary,
                chevron: due > 0,
                onTap: due > 0
                    ? () => nav.push(
                        ReviewScreen.route(
                          subjectId: widget.subjectId,
                          meetingId: widget.meetingId,
                        ),
                      )
                    : null,
              ),
            ListRow(
              leadingSlot: 52,
              leading: const GradientIconTile(icon: Icons.quiz_outlined),
              title: 'Vyzkoušet se před testem',
              subtitle: 'Kvíz z výpisků tohoto předmětu.',
              onTap: () => nav.push(ExamPrepScreen.route(widget.subjectId)),
            ),
            if (total > 0)
              ListRow(
                leadingSlot: 52,
                leading: const GradientIconTile(icon: Icons.list_alt_rounded),
                title: 'Kartičky předmětu',
                subtitle: 'Upravit, pozastavit nebo přidat.',
                onTap: () => nav.push(StudyCardsScreen.route(widget.subjectId)),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Gap.lg),
          child: AiDisclaimer(),
        ),
        const SizedBox(height: Gap.lg),
      ],
    );
  }
}
