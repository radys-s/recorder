import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ai/ai_router.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/inset_group.dart';
import '../../core/widgets/section_header.dart';

/// One line per AI service: whether it has a key, whether it is resting after
/// a limit, when it last answered and how often it was asked this session.
///
/// The picture is the router's own (`AiRouteHealth`), not a separate probe, so
/// what is shown is what the app will actually do with the next request.
class ServiceStatusSection extends ConsumerStatefulWidget {
  const ServiceStatusSection({super.key});

  @override
  ConsumerState<ServiceStatusSection> createState() =>
      _ServiceStatusSectionState();
}

class _ServiceStatusSectionState extends ConsumerState<ServiceStatusSection> {
  late final AiRouteHealth _health = ref.read(aiRouteHealthProvider);
  Map<AiVendor, bool> _keys = const {};

  /// Services whose *current* key was refused — a new key lifts it.
  Map<AiVendor, bool> _refused = const {};

  @override
  void initState() {
    super.initState();
    _health.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    _health.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final stores = {
      AiVendor.groq: ref.read(apiKeyStoreProvider),
      AiVendor.gemini: ref.read(geminiKeyStoreProvider),
      AiVendor.mistral: ref.read(mistralKeyStoreProvider),
      AiVendor.cerebras: ref.read(cerebrasKeyStoreProvider),
      AiVendor.custom: ref.read(customAiKeyStoreProvider),
    };
    final keys = <AiVendor, bool>{};
    final refused = <AiVendor, bool>{};
    for (final e in stores.entries) {
      final key = await e.value.read();
      keys[e.key] = key != null;
      refused[e.key] = key != null && _health.disabled(e.key, key);
    }
    if (mounted) {
      setState(() {
        _keys = keys;
        _refused = refused;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const order = [
      AiVendor.groq,
      AiVendor.gemini,
      AiVendor.cerebras,
      AiVendor.mistral,
      AiVendor.custom,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Stav služeb',
          description:
              'Co aplikace s klíči právě dělá. Služba v pauze se přeskočí a '
              'zkusí se další; čítače platí od spuštění aplikace.',
        ),
        InsetGroup(
          horizontalInset: 0,
          children: [
            for (final v in order)
              ListRow(
                title: v.label,
                subtitle: _line(v),
                subtitleColor: _warn(v) ? scheme.error : null,
                trailing: _counts(v) == null
                    ? null
                    : Text(
                        _counts(v)!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                chevron: false,
                leading: Icon(
                  _icon(v),
                  size: 20,
                  color: _warn(v)
                      ? scheme.error
                      : (_keys[v] ?? false)
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.lg),
      ],
    );
  }

  bool _warn(AiVendor v) => _refused[v] ?? false;

  IconData _icon(AiVendor v) {
    if (_keys[v] != true) return Icons.key_off;
    if (_refused[v] ?? false) return Icons.error_outline;
    if (_health.coolingDown(v)) return Icons.pause_circle_outline;
    return Icons.check_circle_outline;
  }

  String _line(AiVendor v) {
    if (_keys[v] != true) return 'Bez klíče';
    if (_refused[v] ?? false) return 'Klíč odmítnut — ulož nový';
    final until = _health.cooldownUntil(v);
    if (until != null) return 'Pauza do ${DateFormat.Hm().format(until)}';
    final ok = _health.lastSuccess(v);
    if (ok != null) {
      final model = _health.lastModel(v);
      return 'V pořádku · ${DateFormat.Hm().format(ok)}'
          '${model == null ? '' : ' · $model'}';
    }
    return 'Připraveno, zatím nepoužito';
  }

  String? _counts(AiVendor v) {
    final n = _health.requests(v);
    if (n == 0) return null;
    final limits = _health.rateLimits(v);
    return limits == 0 ? '$n×' : '$n× · $limits× limit';
  }
}
