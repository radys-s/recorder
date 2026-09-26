import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../meeting_actions.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/daos/meetings_dao.dart';
import '../../notes_library/notes_library_providers.dart';
import '../../subjects/widgets/subject_badge.dart';

/// What the student reads most after a lesson, one tap from home: the newest
/// AI notes, or — before any exist — the newest saved note.
///
/// Calm on purpose. It is a reading surface, so it has no motion of its own
/// beyond the press feedback every card has.
class LatestNotesCard extends StatelessWidget {
  const LatestNotesCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.content,
    required this.date,
    required this.onTap,
    this.subject,
  });

  /// Latest AI notes of [summary].
  factory LatestNotesCard.lesson({
    required MeetingNote notes,
    required MeetingSummary summary,
    required VoidCallback onTap,
  }) {
    final meeting = summary.meeting;
    return LatestNotesCard(
      eyebrow: 'Poslední výpisky',
      title: isDefaultMeetingTitle(meeting.title)
          ? (summary.subject?.name ?? 'Hodina')
          : meeting.title,
      content: notes.content ?? '',
      date: meeting.createdAt,
      subject: summary.subject,
      onTap: onTap,
    );
  }

  /// Fallback when no lesson has AI notes yet.
  factory LatestNotesCard.saved({
    required SavedNote note,
    required VoidCallback onTap,
  }) => LatestNotesCard(
    eyebrow: 'Uložená poznámka',
    title: note.title,
    content: note.content,
    date: note.updatedAt,
    onTap: onTap,
  );

  final String eyebrow;
  final String title;
  final String content;
  final DateTime date;
  final Subject? subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Pressable(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        eyebrow.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Text(
                      formatDateGroup(date),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (subject != null) ...[
                      const SizedBox(width: Gap.sm),
                      SubjectBadge(subject: subject!),
                    ],
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  notePreview(content),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
