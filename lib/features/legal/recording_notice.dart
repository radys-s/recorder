import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/spacing.dart';

/// Before a recording starts: a reminder that the people in the room have a
/// say in being recorded. True when the student goes on.
///
/// Skipped once they tick „Příště nezobrazovat".
Future<bool> confirmRecordingNotice(BuildContext context, WidgetRef ref) async {
  final prefs = await ref.read(preferencesDaoProvider).current();
  if (prefs.recordingNoticeDismissed) return true;
  if (!context.mounted) return false;
  final result = await showModalBottomSheet<({bool go, bool dismiss})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _RecordingNoticeSheet(),
  );
  if (result == null || !result.go) return false;
  if (result.dismiss) {
    await ref.read(preferencesDaoProvider).setRecordingNoticeDismissed(true);
  }
  return true;
}

class _RecordingNoticeSheet extends StatefulWidget {
  const _RecordingNoticeSheet();

  @override
  State<_RecordingNoticeSheet> createState() => _RecordingNoticeSheetState();
}

class _RecordingNoticeSheetState extends State<_RecordingNoticeSheet> {
  bool _dismiss = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Než začneš nahrávat', style: theme.textTheme.titleLarge),
            const SizedBox(height: Gap.md),
            Text(
              'Hlas a projev lidí chrání zákon (§ 86 občanského zákoníku). '
              'Nahrávej jen se svolením vyučujícího a dalších, kdo budou '
              'slyšet, a podle školního řádu. Nahrávky nešiř dál bez jejich '
              'souhlasu.',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: Gap.sm),
            CheckboxListTile(
              value: _dismiss,
              onChanged: (v) => setState(() => _dismiss = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Příště nezobrazovat'),
            ),
            const SizedBox(height: Gap.sm),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((go: true, dismiss: _dismiss)),
              child: const Text('Mám svolení, nahrávat'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zrušit'),
            ),
          ],
        ),
      ),
    );
  }
}
