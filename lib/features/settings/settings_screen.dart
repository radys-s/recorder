import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../ai/gemini_key_check.dart';
import '../../ai/gemini_models.dart';
import '../../ai/groq_models.dart';
import '../../audio/recording_controller.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/db/tables/preferences_table.dart';
import '../debug/queue_debug_screen.dart';
import '../debug/web_answer_probe.dart';
import 'ai_services_section.dart';
import 'appearance_section.dart';
import 'drive_sync_section.dart';
import '../../legal/data_processors.dart';
import '../legal/data_processor_notice.dart';
import 'lesson_reminders_section.dart';
import 'privacy_section.dart';
import 'storage_section.dart';
import 'study_profile_section.dart';

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
          const AppearanceSection(first: true),
          const SectionHeader(
            title: 'Groq API klíč',
            description:
                'Uložený jen na tomhle zařízení, v systémovém '
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
                  onPressed: _busy || masked.valueOrNull == null
                      ? null
                      : _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Smazat'),
                ),
              ),
            ],
          ),
          const DataProcessorNotice(DataProcessor.groq),
          const _GeminiKeySection(),
          const AiServicesSection(),
          const StudyProfileSection(),
          const _LanguageSection(),
          const _MicTipsSection(),
          const LessonRemindersSection(),
          const StorageSection(),
          const DriveSyncSection(),
          const _SensitivitySection(),
          const _LiveAnswersSection(),
          const _GlobalRulesSection(),
          const PrivacySection(),
          if (kDebugMode) const _DiagnosticsSection(),
        ],
      ),
    );
  }
}

/// The optional Google Gemini key: photos, lookups, card summaries and typed
/// questions with a much larger context. Everything works without it.
class _GeminiKeySection extends ConsumerStatefulWidget {
  const _GeminiKeySection();

  @override
  ConsumerState<_GeminiKeySection> createState() => _GeminiKeySectionState();
}

class _GeminiKeySectionState extends ConsumerState<_GeminiKeySection> {
  final _controller = TextEditingController();
  bool _obscured = true;
  bool _busy = false;

  /// What the last „Ověřit klíč" found; shown on the key card.
  GeminiKeyReport? _report;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(hasGeminiKeyProvider);
    ref.invalidate(maskedGeminiKeyProvider);
    ref.read(geminiModelResolverProvider).reset();
    _report = null;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      _notify('Nejdřív zadej klíč.');
      return;
    }
    try {
      await ref.read(geminiKeyStoreProvider).write(value);
      _controller.clear();
      _invalidate();
      _notify('Gemini klíč uložen.');
    } catch (e) {
      _notify('Klíč se nepodařilo uložit: $e');
    }
  });

  Future<void> _clear() => _run(() async {
    try {
      await ref.read(geminiKeyStoreProvider).delete();
      _invalidate();
      _notify('Gemini klíč smazán.');
    } catch (e) {
      _notify('Klíč se nepodařilo smazat: $e');
    }
  });

  /// A real test: models, the ones picked, one plain and one search call.
  Future<void> _verify() => _run(() async {
    final keys = ref.read(geminiKeyStoreProvider);
    final prefs = ref.read(preferencesDaoProvider);
    final resolver = ref.read(geminiModelResolverProvider)..reset();
    final report = await checkGeminiKey(
      listModels: () => listGeminiModels(keys),
      gemini: ref.read(geminiProvider),
      resolver: resolver,
      override: (await prefs.current()).geminiModelOverride,
    );
    if (!mounted) return;
    setState(() => _report = report);
    final pick = await showDialog<bool>(
      context: context,
      builder: (context) => _GeminiReportDialog(report: report),
    );
    if (pick == true && mounted) await _pickModel(report.selectable);
  });

  Future<void> _pickModel(List<String> ids) async {
    final prefs = ref.read(preferencesDaoProvider);
    final current = (await prefs.current()).geminiModelOverride;
    if (!mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(
                current == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: const Text('Automaticky'),
              subtitle: const Text('Aplikace vybere nejnovější Flash.'),
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final id in ids)
              ListTile(
                leading: Icon(
                  id == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(id),
                onTap: () => Navigator.pop(context, id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await prefs.setGeminiModelOverride(chosen);
    ref.read(geminiModelResolverProvider).reset();
    if (mounted) setState(() => _report = null);
    _notify(
      chosen.isEmpty
          ? 'Model se vybírá automaticky. Ověř klíč znovu.'
          : 'Použije se $chosen. Ověř klíč znovu.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(maskedGeminiKeyProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Google Gemini',
          description:
              'Nepovinné. Umí fotky, dohledávání, shrnutí karet a '
              'odpovídá na otázky z chatu s větším kontextem. Bez klíče vše '
              'běží přes Groq.',
        ),
        Card(
          child: ListTile(
            leading: Icon(masked == null ? Icons.key_off : Icons.key),
            title: Text(masked ?? 'Žádný klíč není uložený'),
            subtitle: Text(
              masked == null
                  ? 'Klíč zdarma dostaneš v Google AI Studiu.'
                  : switch (_report) {
                      final r? when r.works && r.models != null =>
                        'Připojeno · ${r.models!.main}',
                      final r? when !r.works =>
                        'Ověření selhalo — klepni na '
                            'Ověřit klíč pro detail.',
                      _ => 'Uložením nového klíče tenhle přepíšeš.',
                    },
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'Bezplatná verze Gemini může vstupy použít ke zlepšování služeb '
          'Googlu. Posílají se fotky, dohledávání, karty, otázky a text '
          'hodiny, po hodině i celá nahrávka pro vylepšený přepis.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const DataProcessorNotice(DataProcessor.gemini),
        const SizedBox(height: Gap.sm),
        TextField(
          controller: _controller,
          obscureText: _obscured,
          enabled: !_busy,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Nový Gemini klíč',
            hintText: 'AIza...',
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
                onPressed: _busy || masked == null ? null : _clear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Smazat'),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        OutlinedButton.icon(
          onPressed: _busy || masked == null ? null : _verify,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Ověřit klíč'),
        ),
      ],
    );
  }
}

class _GeminiReportDialog extends StatelessWidget {
  const _GeminiReportDialog({required this.report});

  final GeminiKeyReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      icon: Icon(
        report.works ? Icons.check_circle_outline : Icons.error_outline,
      ),
      title: Text(report.works ? 'Gemini funguje' : 'Gemini nefunguje'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final step in report.steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      switch (step.state) {
                        CheckState.ok => Icons.check_circle,
                        CheckState.warn => Icons.warning_amber_rounded,
                        CheckState.fail => Icons.cancel,
                      },
                      size: 20,
                      color: switch (step.state) {
                        CheckState.ok => scheme.primary,
                        CheckState.warn => scheme.tertiary,
                        CheckState.fail => scheme.error,
                      },
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.label, style: text.titleSmall),
                          SelectableText(step.detail, style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (report.selectable.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Jiný model'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Zavřít'),
        ),
      ],
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
          description:
              'Napevno zvolený jazyk drží přepis pohromadě. '
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

/// What actually decides how well a lesson is heard is where the phone lies,
/// not which model reads it afterwards — a voice loses about 6 dB every time
/// it gets twice as far away, and nothing downstream puts that back. Hence a
/// sheet rather than a line of help text.
class _MicTipsSection extends StatelessWidget {
  const _MicTipsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Kvalita zvuku',
          description:
              'Přepis je jen tak dobrý jako nahrávka. Pár věcí s tím udělá '
              'víc než jakékoli nastavení.',
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.mic_none),
            title: const Text('Tipy pro lepší přepis'),
            subtitle: const Text('Kam položit telefon a co pomáhá nejvíc'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showMicTipsSheet(context),
          ),
        ),
      ],
    );
  }
}

/// The advice in the order it matters, which is not the order people try it:
/// distance first, a microphone on the teacher second, everything else after.
Future<void> showMicTipsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tipy pro lepší přepis', style: text.titleLarge),
                const SizedBox(height: Gap.md),
                const _Tip(
                  icon: Icons.place_outlined,
                  title: '1. Vzdálenost rozhoduje',
                  body:
                      'Hlas ztrácí zhruba polovinu hlasitosti pokaždé, když '
                      'se vzdálenost zdvojnásobí. Telefon na první lavici '
                      'slyší vyučujícího mnohem líp než telefon v zadní '
                      'řadě — a žádná AI to zpětně nedoplní.',
                ),
                const _Tip(
                  icon: Icons.table_restaurant_outlined,
                  title: '2. Polož ho na stůl, mikrofonem nahoru',
                  body:
                      'Ne do batohu, ne pod sešit a ne do ruky. Podržení '
                      'v ruce přidává šustění, které přehluší tichou řeč.',
                ),
                const _Tip(
                  icon: Icons.cable,
                  title: '3. Klopový mikrofon na vyučujícím',
                  body:
                      'Bezdrátový nebo USB-C klopák připnutý vyučujícímu je '
                      'jednoznačně nejlepší řešení — vždycky se ale nejdřív '
                      'zeptej, jestli s tím souhlasí. iPhone na připojený '
                      'mikrofon přepne sám.',
                ),
                const _Tip(
                  icon: Icons.bluetooth_disabled,
                  title: '4. Bluetooth sluchátka spíš uškodí',
                  body:
                      'Handsfree profil posílá úzké pásmo a zvuk si ještě '
                      'po svém upraví. Vestavěný mikrofon telefonu je na '
                      'přepis lepší.',
                ),
                const _Tip(
                  icon: Icons.graphic_eq,
                  title: '5. Sleduj varování během hodiny',
                  body:
                      'Když aplikace napíše „Slabý signál", opravdu to znamená, '
                      'že se z místnosti ozývá víc než z vyučujícího. Posunout '
                      'telefon blíž je v tu chvíli účinnější než cokoli jiného.',
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: Gap.xs),
                Text(
                  body,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How readily quiet audio counts as speech. See `SensitivityProfile` for
/// what each step changes. Automatic is the default and almost always right,
/// so the manual choice sits collapsed under „Pokročilé".
class _SensitivitySection extends ConsumerWidget {
  const _SensitivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final selected = prefs.valueOrNull?.micSensitivity;

    return Theme(
      // ExpansionTile draws dividers above and below when open; the other
      // sections have none.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('Pokročilé'),
        subtitle: Text(
          'Citlivost poslechu: ${(selected ?? MicSensitivity.auto).label}',
        ),
        children: [
          _manualSensitivity(ref, ready: prefs.hasValue, selected: selected),
          const SizedBox(height: Gap.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Opravovat přepis podle předmětu'),
            subtitle: const Text(
              'V hodině s předmětem AI opraví špatně slyšená jména a pojmy '
              'podle slovníku a karet. Nic nepřepisuje jinak — původní znění '
              'uvidíš po podržení prstu na textu.',
            ),
            value: prefs.valueOrNull?.contextCorrection ?? true,
            onChanged: prefs.hasValue
                ? (v) =>
                      ref.read(preferencesDaoProvider).setContextCorrection(v)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _manualSensitivity(
    WidgetRef ref, {
    required bool ready,
    required MicSensitivity? selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Citlivost poslechu',
          description:
              'Automaticky si na začátku nahrávání změří místnost a '
              'průběžně se jí přizpůsobuje. Hodně zachytí i tichou schůzku '
              'nebo vzdáleného mluvčího, jen občas přepíše i šum. Málo se hodí '
              'do hlučné místnosti. Změna platí hned, i během nahrávání.',
        ),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final value in MicSensitivity.ordered)
              ChoiceChip(
                label: Text(value.label),
                selected: value == (selected ?? MicSensitivity.auto),
                onSelected: ready
                    ? (_) => ref
                          .read(preferencesDaoProvider)
                          .setMicSensitivity(value)
                    : null,
              ),
          ],
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
          description:
              'Když někdo na schůzce položí otázku, aplikace k ní '
              'během nahrávání ukáže odpověď. Nikdy nemluví ani nevyrušuje '
              '— čtení je na tobě.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: prefs.hasValue
              ? (value) => ref
                    .read(preferencesDaoProvider)
                    .setLiveAnswersEnabled(value)
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
            'Vyžaduje Gemini klíč. Když na otázku neodpovídá samotná'
            ' schůzka, aplikace ji vyhledá na internetu a ukáže i zdroje.'
            ' Odchází jen samotná otázka, nikdy přepis schůzky.',
          ),
        ),
      ],
    );
  }
}

/// Rules for every answer, everywhere. A subject's rules and what is typed in
/// a lesson's chat override them.
class _GlobalRulesSection extends ConsumerStatefulWidget {
  const _GlobalRulesSection();

  @override
  ConsumerState<_GlobalRulesSection> createState() =>
      _GlobalRulesSectionState();
}

class _GlobalRulesSectionState extends ConsumerState<_GlobalRulesSection> {
  final _controller = TextEditingController();
  bool _loaded = false;
  String _saved = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(preferencesDaoProvider).setGlobalRules(_controller.text);
    if (!mounted) return;
    setState(() => _saved = _controller.text.trim());
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Pravidla uložena.')));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    // Filled once, from the first value; later emissions come from unrelated
    // settings and must not overwrite what is being typed.
    if (!_loaded && prefs.hasValue) {
      _loaded = true;
      _saved = prefs.requireValue.globalRules ?? '';
      _controller.text = _saved;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Pravidla pro AI',
          description:
              'Platí pro všechny odpovědi. Pravidla předmětu a to, '
              'co napíšeš do chatu během hodiny, mají přednost.',
        ),
        TextField(
          controller: _controller,
          enabled: _loaded,
          minLines: 2,
          maxLines: 6,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Např. Odpovídej stručně a vždy uveď příklad.',
            border: OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            style: tonalButtonStyle(context),
            onPressed: _loaded && _controller.text.trim() != _saved
                ? _save
                : null,
            icon: const Icon(Icons.check),
            label: const Text('Uložit pravidla'),
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
    final recording = ref.watch(
      recordingControllerProvider.select((s) => s.isRecording),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Diagnostika',
          description:
              'Jen ve vývojářském buildu. Emulátorový mikrofon '
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
          subtitle: const Text(
            'Ověří Gemini vyhledávání včetně skutečných zdrojů.',
          ),
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

  /// One fixed question through the same grounded search as a live answer.
  Future<void> _probeWebAnswers(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Ověřuji vyhledávání a zdroje…')),
      );

    final lines = await WebAnswerProbe(ref.read(webAnswerServiceProvider))
        .run();
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
