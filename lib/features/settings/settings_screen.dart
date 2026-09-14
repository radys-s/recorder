import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/groq_models.dart';
import '../../audio/recording_controller.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/db/tables/preferences_table.dart';
import '../debug/queue_debug_screen.dart';
import '../debug/web_answer_probe.dart';

/// Groq API key entry. Phase 1 has nothing else to configure, apart from the
/// debug-only diagnostics section at the bottom.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _controller = TextEditingController();
  bool _obscured = true;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _invalidateKeyProviders() {
    ref.invalidate(hasApiKeyProvider);
    ref.invalidate(maskedApiKeyProvider);
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      _notify('Nejdřív zadej klíč.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(apiKeyStoreProvider).write(value);
      _controller.clear();
      _invalidateKeyProviders();
      _notify('Klíč uložen.');
    } catch (e) {
      _notify('Klíč se nepodařilo uložit: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiKeyStoreProvider).delete();
      _invalidateKeyProviders();
      _notify('Klíč smazán.');
    } catch (e) {
      _notify('Klíč se nepodařilo smazat: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(maskedApiKeyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nastavení')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          const SectionHeader(
            first: true,
            title: 'Groq API klíč',
            description: 'Uložený jen na tomhle zařízení, v systémovém '
                'úložišti klíčů. Odesílá se do Groqu a nikam jinam.',
          ),
          Card(
            child: ListTile(
              leading: Icon(
                masked.valueOrNull == null ? Icons.key_off : Icons.key,
                color: masked.valueOrNull == null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              title: Text(masked.valueOrNull ?? 'Žádný klíč není uložený'),
              subtitle: Text(
                masked.valueOrNull == null
                    ? 'Bez klíče se přepis nespustí.'
                    : 'Uložením nového klíče tenhle přepíšeš.',
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _controller,
            obscureText: _obscured,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Nový klíč',
              hintText: 'gsk_...',
              suffixIcon: IconButton(
                icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
                tooltip: _obscured ? 'Zobrazit klíč' : 'Skrýt klíč',
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Uložit'),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || masked.valueOrNull == null ? null : _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Smazat'),
                ),
              ),
            ],
          ),
          const _LanguageSection(),
          const _SensitivitySection(),
          const _LiveAnswersSection(),
          if (kDebugMode) const _DiagnosticsSection(),
        ],
      ),
    );
  }
}

/// Which language Whisper is told the meeting is in.
///
/// Auto-detect decides per chunk, not per meeting, so a quiet or noisy stretch
/// of Czech can come back as another language halfway through a transcript.
/// Pinning it is the fix — at the cost of removing Whisper's option of
/// returning nothing over silence, which is why the sanitizer exists.
class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final selected = prefs.valueOrNull?.transcriptLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Jazyk přepisu',
          description: 'Napevno zvolený jazyk drží přepis pohromadě. '
              'Automaticky ho hádá Whisper znovu u každého úseku, takže se '
              'uprostřed schůzky může přepnout jinam.',
        ),
        SegmentedButton<TranscriptLanguage>(
          segments: [
            for (final value in TranscriptLanguage.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          // The stream has no value for the first frame; showing Czech (the
          // default) beats an empty selection that flickers.
          selected: {selected ?? TranscriptLanguage.czech},
          onSelectionChanged: prefs.hasValue
              ? (set) => ref
                  .read(preferencesDaoProvider)
                  .setTranscriptLanguage(set.first)
              : null,
        ),
      ],
    );
  }
}

/// How readily quiet audio counts as speech. See `SensitivityProfile` for
/// what each step changes; the same setting is on the meeting screen's app
/// bar, since a meeting that is too quiet is noticed while it is running.
class _SensitivitySection extends ConsumerWidget {
  const _SensitivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final selected = prefs.valueOrNull?.micSensitivity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Citlivost poslechu',
          description: 'Hodně zachytí i tichou schůzku nebo vzdáleného '
              'mluvčího a tichý zvuk zesílí, jen občas přepíše i šum. '
              'Málo se hodí do hlučné místnosti. Změna platí hned, i během '
              'nahrávání.',
        ),
        SegmentedButton<MicSensitivity>(
          segments: [
            for (final value in MicSensitivity.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {selected ?? MicSensitivity.medium},
          onSelectionChanged: prefs.hasValue
              ? (set) =>
                  ref.read(preferencesDaoProvider).setMicSensitivity(set.first)
              : null,
        ),
      ],
    );
  }
}

/// The global default for live answering. The same flag is reachable from the
/// meeting screen's app bar, because that is where the user is when they
/// realise they want it.
class _LiveAnswersSection extends ConsumerWidget {
  const _LiveAnswersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final enabled = prefs.valueOrNull?.liveAnswersEnabled ?? false;
    final web = prefs.valueOrNull?.webAnswersEnabled ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Živé odpovědi',
          description: 'Když někdo na schůzce položí otázku, aplikace k ní '
              'během nahrávání ukáže odpověď. Nikdy nemluví ani nevyrušuje '
              '— čtení je na tobě.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: prefs.hasValue
              ? (value) =>
                  ref.read(preferencesDaoProvider).setLiveAnswersEnabled(value)
              : null,
          title: const Text('Odpovídat na otázky'),
          subtitle: const Text(
            'Zapni to před začátkem nahrávání — zvuk se pak krájí na kratší '
            'úseky, aby odpověď stihla přijít včas.',
          ),
        ),
        // Dependent on the switch above, and off by default: this is the one
        // setting in the app that sends anything derived from a meeting to a
        // third party, so it has to be a decision the user makes rather than
        // one they discover.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: web,
          onChanged: prefs.hasValue && enabled
              ? (value) =>
                  ref.read(preferencesDaoProvider).setWebAnswersEnabled(value)
              : null,
          title: const Text('Hledat i na internetu'),
          subtitle: const Text(
            'Když na otázku neodpovídá samotná schůzka, aplikace ji vyhledá '
            'na internetu a ukáže i zdroje. Odchází jen samotná otázka, '
            'nikdy přepis schůzky.',
          ),
        ),
      ],
    );
  }
}

/// Debug-build-only controls for driving the pipeline from a file instead of
/// the microphone. Wrapped in a `kDebugMode` check at the call site so it can
/// never reach a release build.
class _DiagnosticsSection extends ConsumerWidget {
  const _DiagnosticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replay = ref.watch(replayAudioEnabledProvider);
    final loop = ref.watch(replayAudioLoopProvider);
    // Switching the source mid-recording would leave stop() holding a
    // different object than start() opened, so the toggles are locked while
    // a recording is running.
    final recording =
        ref.watch(recordingControllerProvider.select((s) => s.isRecording));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Diagnostika',
          description: 'Jen ve vývojářském buildu. Emulátorový mikrofon '
              'dodává jen ticho, takže se pipeline testuje přehráváním WAV '
              'souboru.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: replay,
          onChanged: recording
              ? null
              : (v) => ref.read(replayAudioEnabledProvider.notifier).state = v,
          title: const Text('Přehrávat WAV místo mikrofonu'),
          subtitle: Text(kReplayAudioFileNames.join(' nebo ')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: loop,
          onChanged: recording || !replay
              ? null
              : (v) => ref.read(replayAudioLoopProvider.notifier).state = v,
          title: const Text('Přehrávat dokola'),
          subtitle: const Text('Pro dlouhé zátěžové běhy.'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.list_alt_outlined),
          title: const Text('Dostupné modely'),
          subtitle: const Text('Co tenhle klíč u Groqu skutečně smí volat.'),
          onTap: () => _showModels(context, ref),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.travel_explore_outlined),
          title: const Text('Zkouška webové odpovědi'),
          subtitle: const Text('Projede varianty požadavku a ukáže, '
              'která u Groqu projde.'),
          onTap: () => _probeWebAnswers(context, ref),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Fronta přepisů'),
          subtitle: const Text('Syrové řádky fronty a testovací data.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const QueueDebugScreen()),
          ),
        ),
      ],
    );
  }

  /// One tap, one fixed question, every request shape the web hop could use.
  /// Reproducing a web-answer failure through the normal path costs two
  /// minutes of replayed audio and gives one data point; this gives all of
  /// them, which is what makes a limit on Groq's side distinguishable from a
  /// bad request on ours.
  Future<void> _probeWebAnswers(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Zkouším varianty, viz log…')),
      );

    final lines =
        await WebAnswerProbe(ref.read(llmProvider)).run();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zkouška webové odpovědi'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SelectableText(line),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  /// Model ids drift, and a retired one comes back as a 404 that looks like an
  /// app bug. Asking the account settles it without the key ever leaving the
  /// device.
  Future<void> _showModels(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    List<String> ids;
    try {
      ids = await listGroqModels(ref.read(apiKeyStoreProvider));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Nepovedlo se: $e')));
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dostupné modely'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final id in ids)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SelectableText(id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }
}
