import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/accent.dart';
import '../../ai/ai_router.dart';
import '../../ai/llm_provider.dart';
import '../../ai/openai_compatible_provider.dart';
import '../../core/constants.dart';
import '../../ai/custom_endpoint.dart';
import '../../core/providers.dart';
import '../../core/redaction.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/secure/api_key_store.dart';
import '../../legal/data_processors.dart';
import '../legal/data_processor_notice.dart';

/// Extra text services behind the router. Each is optional; with more keys
/// the app simply runs out of free limits later.
class AiServicesSection extends StatelessWidget {
  const AiServicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Další AI služby',
          description:
              'Nepovinné bezplatné zálohy. Když jedné službě dojde limit nebo '
              'je přetížená, aplikace hned použije další uložený klíč.',
        ),
        _ServiceKeyCard(
          vendor: AiVendor.cerebras,
          hint:
              'Klíč zdarma na cloud.cerebras.ai. Velmi rychlý, jen text — '
              'je to nejlepší první záloha pro poznámky a opravy přepisu.',
          privacy: 'Posílá se text přepisu a otázek, nikdy zvuk.',
        ),
        _ServiceKeyCard(
          vendor: AiVendor.mistral,
          hint:
              'Klíč zdarma v La Plateforme (console.mistral.ai), tarif '
              'Experiment. Umí i fotky, když Gemini nejde.',
          privacy:
              'Bezplatný tarif může vstupy použít k tréninku — vypnout '
              'to jde v nastavení účtu Mistral (Privacy).',
        ),
        _ServiceKeyCard(
          vendor: AiVendor.custom,
          hint:
              'Například školní model. Musí umět OpenAI rozhraní '
              '(/chat/completions). Když klíč nepotřebuje, zadej cokoli.',
          privacy: 'Používá se jako první, pokud je vyplněný.',
        ),
      ],
    );
  }
}

class _ServiceKeyCard extends ConsumerStatefulWidget {
  const _ServiceKeyCard({
    required this.vendor,
    required this.hint,
    required this.privacy,
  });

  final AiVendor vendor;
  final String hint;
  final String privacy;

  @override
  ConsumerState<_ServiceKeyCard> createState() => _ServiceKeyCardState();
}

class _ServiceKeyCardState extends ConsumerState<_ServiceKeyCard> {
  final _key = TextEditingController();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  bool _obscured = true;
  bool _busy = false;
  String? _masked;
  String? _verified;

  bool get _custom => widget.vendor == AiVendor.custom;

  ApiKeyStore get _store => switch (widget.vendor) {
    AiVendor.mistral => ref.read(mistralKeyStoreProvider),
    AiVendor.cerebras => ref.read(cerebrasKeyStoreProvider),
    AiVendor.custom => ref.read(customAiKeyStoreProvider),
    AiVendor.groq => ref.read(apiKeyStoreProvider),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final masked = await _store.maskedKey();
    final base = _custom
        ? await ref.read(customAiBaseUrlStoreProvider).read()
        : null;
    final model = _custom
        ? await ref.read(customAiModelStoreProvider).read()
        : null;
    if (!mounted) return;
    setState(() {
      _masked = masked;
      if (base != null) _baseUrl.text = base;
      if (model != null) _model.text = model;
    });
  }

  @override
  void dispose() {
    _key.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
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
    } catch (e) {
      _notify('Nepodařilo se: ${_friendly(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final key = _key.text.trim();
    var hostChanged = false;
    if (_custom) {
      final model = _model.text.trim();
      final endpoint = checkCustomEndpoint(_baseUrl.text);
      if (!endpoint.valid) {
        _notify(endpoint.problem!);
        return;
      }
      if (model.isEmpty) {
        _notify('Vyplň adresu i model.');
        return;
      }
      // The saved key belongs to the service it was typed for. Pointing the
      // address somewhere else must not carry it along.
      final storedBase = ref.read(customAiBaseUrlStoreProvider);
      final before = checkCustomEndpoint(await storedBase.read());
      if (_masked != null && before.valid && before.host != endpoint.host) {
        await _store.delete();
        _masked = null;
        hostChanged = true;
      }
      await storedBase.write(endpoint.url!);
      await ref.read(customAiModelStoreProvider).write(model);
      _baseUrl.text = endpoint.url!;
      if (key.isEmpty && _masked == null) {
        _notify(
          hostChanged
              ? 'Adresa se změnila, uložený klíč jsem proto smazal. '
                    'Zadej klíč znovu.'
              : 'Doplň ještě klíč (když ho služba nechce, cokoli).',
        );
        if (hostChanged) await _load();
        return;
      }
    } else if (key.isEmpty) {
      _notify('Nejdřív zadej klíč.');
      return;
    }
    if (key.isNotEmpty) await _store.write(key);
    _key.clear();
    _verified = null;
    ref.invalidate(hasVisionKeyProvider);
    await _load();
    final hint = key.isEmpty
        ? null
        : apiKeyFormatHint(widget.vendor.label, cleanApiKey(key));
    _notify('${widget.vendor.label}: uloženo.${hint == null ? '' : ' $hint'}');
  });

  Future<void> _clear() => _run(() async {
    await _store.delete();
    if (_custom) {
      await ref.read(customAiBaseUrlStoreProvider).delete();
      await ref.read(customAiModelStoreProvider).delete();
      _baseUrl.clear();
      _model.clear();
    }
    _verified = null;
    ref.invalidate(hasVisionKeyProvider);
    await _load();
    _notify('${widget.vendor.label}: smazáno.');
  });

  Future<void> _verify() => _run(() async {
    // Only the address that was saved: a typed-but-unsaved one would receive
    // the stored key without the student ever having confirmed it.
    final String base;
    if (_custom) {
      final saved = checkCustomEndpoint(
        await ref.read(customAiBaseUrlStoreProvider).read(),
      );
      if (!saved.valid) {
        setState(() => _verified = saved.problem);
        return;
      }
      base = saved.url!;
    } else {
      base = switch (widget.vendor) {
        AiVendor.mistral => kMistralBaseUrl,
        AiVendor.cerebras => kCerebrasBaseUrl,
        _ => kGroqBaseUrl,
      };
    }
    try {
      final ids = await listOpenAiModels(
        _store,
        vendor: widget.vendor.label,
        baseUrl: base,
      );
      final wanted = switch (widget.vendor) {
        AiVendor.mistral => {...kMistralFastModels, ...kMistralStrongModels},
        AiVendor.cerebras => kCerebrasModels.toSet(),
        _ => {(await ref.read(customAiModelStoreProvider).read()) ?? ''},
      };
      final found = wanted.where(ids.contains).toList();
      setState(
        () => _verified = found.isEmpty
            ? 'Klíč funguje (${ids.length} modelů), ale žádný z očekávaných '
                  'tam není — aplikace zkusí náhradní.'
            : 'Připojeno · ${found.first}',
      );
    } catch (e) {
      setState(() => _verified = 'Ověření selhalo: ${_friendly(e)}');
    }
  });

  String _friendly(Object e) => e is AiException
      ? redactSecrets(e.message)
      : e is ApiKeyProblem
      ? e.message
      : 'Nastala neočekávaná chyba.';

  String _status() {
    final health = ref.read(aiRouteHealthProvider);
    final v = widget.vendor;
    if (health.anyDisabled(v)) return 'Klíč odmítnut — ulož nový.';
    final until = health.cooldownUntil(v);
    if (until != null) {
      return 'Limit — pauza do ${DateFormat.Hm().format(until)}';
    }
    final last = health.lastModel(v);
    if (_verified != null) return _verified!;
    if (last != null) return 'Naposledy odpověděl · $last';
    return _masked == null ? widget.hint : 'Uloženo, zatím nepoužito.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _masked == null ? Icons.key_off : Icons.key,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(
                      widget.vendor.label,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (_masked != null) Text(_masked!, style: muted),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(_status(), style: muted),
              const SizedBox(height: Gap.md),
              if (_custom) ...[
                TextField(
                  controller: _baseUrl,
                  enabled: !_busy,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Adresa',
                    hintText: 'https://ai.skola.cz/v1',
                  ),
                ),
                const SizedBox(height: Gap.sm),
                TextField(
                  controller: _model,
                  enabled: !_busy,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                const SizedBox(height: Gap.sm),
              ],
              TextField(
                controller: _key,
                obscureText: _obscured,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: _custom
                      ? 'Klíč'
                      : 'Nový ${widget.vendor.label} klíč',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: _obscured ? 'Zobrazit klíč' : 'Skrýt klíč',
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  FilledButton.tonal(
                    style: tonalButtonStyle(context),
                    onPressed: _busy ? null : _save,
                    child: const Text('Uložit'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _masked == null ? null : _verify,
                    child: const Text('Ověřit'),
                  ),
                  TextButton(
                    onPressed: _busy || _masked == null ? null : _clear,
                    child: const Text('Smazat'),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(widget.privacy, style: muted),
              DataProcessorNotice(switch (widget.vendor) {
                AiVendor.mistral => DataProcessor.mistral,
                AiVendor.cerebras => DataProcessor.cerebras,
                AiVendor.groq => DataProcessor.groq,
                AiVendor.custom => DataProcessor.custom,
              }),
            ],
          ),
        ),
      ),
    );
  }
}
