import 'package:flutter/material.dart';

import '../../../core/spacing.dart';
import '../timetable.dart';

typedef SlotInput = ({int weekday, int startMinute, int endMinute});

/// Asks for one lesson in the timetable: a weekday and a time range.
/// Resolves to null when cancelled.
Future<SlotInput?> showTimetableSlotDialog(
  BuildContext context, {
  DateTime? now,
}) {
  final today = (now ?? DateTime.now()).weekday;
  return showDialog<SlotInput>(
    context: context,
    builder: (_) => _SlotDialog(initialWeekday: today > 5 ? 1 : today),
  );
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({required this.initialWeekday});

  final int initialWeekday;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  static const _lessonMinutes = 45;

  late int _weekday = widget.initialWeekday;
  int _start = 8 * 60;
  int _end = 8 * 60 + _lessonMinutes;

  bool get _valid => _end > _start;

  Future<void> _pickStart() async {
    final picked = await _pick(_start);
    if (picked == null) return;
    setState(() {
      final length = _end - _start;
      _start = picked;
      // Moving the start keeps the lesson's length, as long as it fits the day.
      _end = (picked + (length > 0 ? length : _lessonMinutes))
          .clamp(picked + 1, 24 * 60);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pick(_end);
    if (picked == null) return;
    setState(() => _end = picked == 0 ? 24 * 60 : picked);
  }

  Future<int?> _pick(int minute) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60),
    );
    return time == null ? null : time.hour * 60 + time.minute;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Přidat hodinu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (var day = 1; day <= 7; day++)
                ChoiceChip(
                  label: Text(kWeekdayShort[day - 1]),
                  tooltip: kWeekdayLong[day - 1],
                  selected: day == _weekday,
                  onSelected: (_) => setState(() => _weekday = day),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickStart,
                  child: Text('Od ${formatMinuteOfDay(_start)}'),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickEnd,
                  child: Text('Do ${formatMinuteOfDay(_end)}'),
                ),
              ),
            ],
          ),
          if (!_valid) ...[
            const SizedBox(height: Gap.sm),
            Text(
              'Hodina musí skončit až po začátku.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop((
                    weekday: _weekday,
                    startMinute: _start,
                    endMinute: _end,
                  ))
              : null,
          child: const Text('Přidat'),
        ),
      ],
    );
  }
}
