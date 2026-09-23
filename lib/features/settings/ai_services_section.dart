import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ai/ai_router.dart';
import '../../ai/llm_provider.dart';
import '../../ai/openai_compatible_provider.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/secure/api_key_store.dart';

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
    if (_custom) {
      final base = _baseUrl.text.trim();
      final model = _model.text.trim();
      if (base.isEmpty || model.isEmpty) {
        _notify('Vyplň adresu i model.');
        return;
      }
      await ref.read(customAiBaseUrlStoreProvider).write(base);
      await ref.read(customAiModelStoreProvider).write(model);
      if (key.isEmpty && _masked == null) {
        _notify('Doplň ještě klíč (když ho služba nechce, cokoli).');
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
    _notify('${widget.vendor.label}: uloženo.');
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
    final base = switch (widget.vendor) {
      AiVendor.mistral => kMistralBaseUrl,
      AiVendor.cerebras => kCerebrasBaseUrl,
      AiVendor.groq => kGroqBaseUrl,
      AiVendor.custom => _baseUrl.text.trim(),
    };
    try {
      final ids = await listOpenAiModels(
        _store,
        vendor: widget.vendor.label,
        baseUrl: base,
      );
      final wanted = switch (widget.vendor) {
        AiVendor.mistral => {...kMistralFastModels, ...kMistralStrongModels},
        AiVendor.cerebras => kCerebrasModels.toSet(),
        _ => {_model.text.trim()},
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

  String _friendly(Object e) =>
      e is AiException ? e.message : 'Nastala neočekávaná chyba.';

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
            ],
          ),
        ),
      ),
    );
  }
}
