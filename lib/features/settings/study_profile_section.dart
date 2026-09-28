import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/db/tables/preferences_table.dart';

/// „Studium": school, school type, field and year. Every subject's course
/// line is built from these, so AI answers and plans fit the student's level.
class StudyProfileSection extends ConsumerStatefulWidget {
  const StudyProfileSection({super.key});

  @override
  ConsumerState<StudyProfileSection> createState() =>
      _StudyProfileSectionState();
}

class _StudyProfileSectionState extends ConsumerState<StudyProfileSection> {
  final _school = TextEditingController();
  final _field = TextEditingController();
  SchoolType? _type;
  int? _year;
  bool _loaded = false;
  ({String school, SchoolType? type, String field, int? year})? _saved;

  ({String school, SchoolType? type, String field, int? year}) get _current => (
    school: _school.text.trim(),
    type: _type,
    field: _field.text.trim(),
    year: _year,
  );

  @override
  void dispose() {
    _school.dispose();
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(preferencesDaoProvider)
        .setStudyProfile(
          schoolName: _school.text,
          schoolType: _type,
          studyField: _field.text,
          studyYear: _year,
        );
    if (!mounted) return;
    setState(() => _saved = _current);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Studium uloženo.')));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    // Filled once; later emissions come from other settings and must not
    // overwrite what is being typed.
    if (!_loaded && prefs.hasValue) {
      final p = prefs.requireValue;
      _loaded = true;
      _school.text = p.schoolName ?? '';
      _field.text = p.studyField ?? '';
      _type = p.schoolType;
      _year = p.studyYear;
      _saved = _current;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Studium',
          description:
              'Podle školy a ročníku AI odhadne tematický plán a odpovídá '
              'na úrovni, kterou se učíš.',
        ),
        TextField(
          controller: _school,
          enabled: _loaded,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Škola',
            hintText: 'Třeba: SPŠE Ječná',
          ),
        ),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final t in SchoolType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: _type == t,
                onSelected: _loaded
                    ? (on) => setState(() => _type = on ? t : null)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _field,
                enabled: _loaded,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Obor',
                  hintText: 'Třeba: Informační technologie',
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int?>(
                key: ValueKey(_loaded),
                initialValue: _year,
                decoration: const InputDecoration(labelText: 'Ročník'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (var y = 1; y <= 10; y++)
                    DropdownMenuItem(value: y, child: Text('$y. ročník')),
                ],
                onChanged: _loaded ? (v) => setState(() => _year = v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            style: tonalButtonStyle(context),
            onPressed: _loaded && _current != _saved ? _save : null,
            icon: const Icon(Icons.check),
            label: const Text('Uložit studium'),
          ),
        ),
      ],
    );
  }
}
