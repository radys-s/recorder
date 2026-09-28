import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../ai/gemini_provider.dart';
import '../../ai/photo_text_service.dart' show geminiFailureText;
import '../../ai/timetable_import.dart';
import '../../core/photo_picker.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/db/app_database.dart' show appDatabaseProvider;
import '../../stt/transcript_sanitizer.dart' show normalizeForArtifactMatch;
import 'timetable.dart';

enum _Source { gallery, camera }

/// Picks timetable screenshots and opens the review. Explains instead when
/// there is no Gemini or Mistral key, since only those read pictures.
Future<void> importTimetableFlow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  ref.invalidate(hasVisionKeyProvider);
  if (!await ref.read(hasVisionKeyProvider.future)) {
    ref.invalidate(hasGeminiKeyProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Rozvrh z obrázku čte Gemini nebo Mistral. Přidej klíč v '
            'Nastavení.',
          ),
        ),
      );
    return;
  }
  if (!context.mounted) return;
  final source = await showModalBottomSheet<_Source>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Vybrat screenshot'),
            subtitle: const Text('Třeba z Bakalářů. Klidně víc obrázků.'),
            onTap: () => Navigator.pop(context, _Source.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Vyfotit rozvrh'),
            onTap: () => Navigator.pop(context, _Source.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;
  final picker = ref.read(photoPickerProvider);
  final List<PickedPhoto> photos;
  try {
    photos = source == _Source.gallery
        ? await picker.pickPages()
        : [?await picker.takePhoto()];
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Obrázek se nepodařilo otevřít.')),
    );
    return;
  }
  if (photos.isEmpty) return;
  await navigator.push(TimetableImportScreen.route(photos));
}

/// Reads the picked screenshots and lets the student check the lessons before
/// they land in the timetable. Nothing is written until „Přidat".
class TimetableImportScreen extends ConsumerStatefulWidget {
  const TimetableImportScreen({super.key, required this.photos});

  final List<PickedPhoto> photos;

  static Route<void> route(List<PickedPhoto> photos) =>
      MaterialPageRoute(builder: (_) => TimetableImportScreen(photos: photos));

  @override
  ConsumerState<TimetableImportScreen> createState() =>
      _TimetableImportScreenState();
}

class _TimetableImportScreenState extends ConsumerState<TimetableImportScreen> {
  List<ImportedLesson>? _lessons;
  List<bool> _chosen = const [];
  List<String> _known = const [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() {
      _lessons = null;
      _error = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      final known = [for (final s in await db.savedNotesDao.folders()) s.name];
      final lessons = await ref.read(timetableImportServiceProvider).read([
        for (final p in widget.photos) LlmImage(p.bytes, mimeType: p.mimeType),
      ], knownSubjects: known);
      if (!mounted) return;
      setState(() {
        _known = known;
        _lessons = lessons;
        _chosen = List.filled(lessons.length, true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = geminiFailureText(e));
    }
  }

  bool _isNew(String subject) {
    final key = normalizeForArtifactMatch(subject);
    return !_known.any((k) => normalizeForArtifactMatch(k) == key);
  }

  Future<void> _rename(int index) async {
    final lesson = _lessons![index];
    final name = await showTextInputDialog(
      context,
      title: 'Předmět',
      initialValue: lesson.subject,
      label: 'Název předmětu',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final old = normalizeForArtifactMatch(lesson.subject);
    final clean = matchSubjectName(name.trim(), _known) ?? name.trim();
    // Renaming one lesson renames the subject everywhere in the import — the
    // model spells a subject the same way in every cell.
    setState(() {
      _lessons = [
        for (final l in _lessons!)
          normalizeForArtifactMatch(l.subject) == old
              ? l.copyWith(subject: clean)
              : l,
      ];
    });
  }

  Future<void> _save() async {
    final lessons = _lessons!;
    final picked = [
      for (var i = 0; i < lessons.length; i++)
        if (_chosen[i]) lessons[i],
    ];
    if (picked.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final outcome = await saveImportedTimetable(
        ref.read(appDatabaseProvider),
        picked,
      );
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(importSummary(outcome))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Rozvrh se nepodařilo uložit.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessons = _lessons;
    final count = _chosen.where((c) => c).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Rozvrh z obrázku')),
      body: _error != null
          ? EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Rozvrh se nepodařilo přečíst',
              message: _error!,
              action: FilledButton.tonal(
                style: tonalButtonStyle(context),
                onPressed: _read,
                child: const Text('Zkusit znovu'),
              ),
            )
          : lessons == null
          ? const _Reading()
          : _buildList(lessons),
      bottomNavigationBar: lessons == null || _error != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(Gap.lg),
              child: FilledButton(
                onPressed: count == 0 || _saving ? null : _save,
                child: Text(
                  count == 0 ? 'Nic nevybráno' : 'Přidat ${lessonCount(count)}',
                ),
              ),
            ),
    );
  }

  Widget _buildList(List<ImportedLesson> lessons) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
        child: Text(
          'Zkontroluj hodiny. Klepnutím na název předmět přejmenuješ, '
          'odškrtnuté hodiny se nepřidají.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
    int? day;
    for (var i = 0; i < lessons.length; i++) {
      final l = lessons[i];
      if (l.weekday != day) {
        day = l.weekday;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xs),
            child: Text(
              kWeekdayLong[l.weekday - 1],
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
        );
      }
      final isNew = _isNew(l.subject);
      rows.add(
        CheckboxListTile(
          value: _chosen[i],
          onChanged: (v) => setState(() => _chosen[i] = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: InkWell(onTap: () => _rename(i), child: Text(l.subject)),
          subtitle: Text(
            [
              '${formatMinuteOfDay(l.startMinute)}–'
                  '${formatMinuteOfDay(l.endMinute)}',
              if (l.timeGuessed) 'čas odhadnut',
              if (isNew) 'nový předmět',
            ].join(' · '),
          ),
          secondary: IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Přejmenovat předmět',
            onPressed: () => _rename(i),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: rows,
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: Gap.lg),
          Text('Čtu rozvrh…', style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            'Gemini hledá předměty, dny a časy.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// `1 hodinu`, `3 hodiny`, `5 hodin`.
String lessonCount(int n) => switch (n) {
  1 => '1 hodinu',
  >= 2 && <= 4 => '$n hodiny',
  _ => '$n hodin',
};

/// What the snackbar says after an import.
String importSummary(TimetableImportOutcome o) {
  final parts = <String>[
    o.slotsAdded == 0
        ? 'Nic nového k přidání'
        : 'Přidáno do rozvrhu: ${lessonCount(o.slotsAdded)}',
    if (o.subjectsCreated == 1) '1 nový předmět',
    if (o.subjectsCreated >= 2 && o.subjectsCreated <= 4)
      '${o.subjectsCreated} nové předměty',
    if (o.subjectsCreated >= 5) '${o.subjectsCreated} nových předmětů',
    if (o.skipped > 0) 'už v rozvrhu: ${o.skipped}',
  ];
  return '${parts.join(' · ')}.';
}
