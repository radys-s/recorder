import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/inset_group.dart';
import '../../legal/legal_texts.dart';
import 'legal_doc_screen.dart';

/// Shows [child] only once the student has agreed to the current terms.
///
/// A newer [kTermsVersion] asks again. A preferences row that cannot be read
/// lets the app through: a broken database must not lock the student out of
/// their own notes.
class ConsentGate extends ConsumerWidget {
  const ConsentGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    return prefs.when(
      loading: () => const Scaffold(),
      error: (_, _) => child,
      data: (p) => p.termsAcceptedVersion >= kTermsVersion
          ? child
          : ConsentScreen(updated: p.termsAcceptedVersion > 0),
    );
  }
}

/// The first-run agreement: the two texts and three things the student
/// confirms before the app opens.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, this.updated = false, this.now});

  /// True when they agreed to an older version and are asked again.
  final bool updated;

  final DateTime Function()? now;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _recording = false;
  bool _ai = false;
  bool _age = false;
  bool _busy = false;

  bool get _ready => _recording && _ai && _age;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(preferencesDaoProvider)
          .acceptTerms(kTermsVersion, (widget.now ?? DateTime.now)());
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Souhlas se nepodařilo uložit, zkus to znovu.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.xl),
          children: [
            Text(
              widget.updated ? 'Změnily se podmínky' : 'Vítej v Aftermindu',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              widget.updated
                  ? 'Než budeš pokračovat, projdi si prosím novou verzi a '
                        'potvrď ji.'
                  : 'Aftermind nahrává hodiny a dělá z nich přepis a výpisky. '
                        'Tvoje data zůstávají v telefonu, kromě toho, co '
                        'pošleš do služeb umělé inteligence.',
              style: muted,
            ),
            const SizedBox(height: Gap.xl),
            InsetGroup(
              label: 'Přečti si',
              horizontalInset: 0,
              dividerIndent: ListRow.textIndent + 12,
              children: [
                ListRow(
                  leadingSlot: ListRow.leadingWidth + 12,
                  title: kTermsOfUse.title,
                  leading: const Icon(Icons.gavel_outlined),
                  chevron: true,
                  onTap: () => Navigator.of(
                    context,
                  ).push(LegalDocScreen.route(kTermsOfUse)),
                ),
                ListRow(
                  leadingSlot: ListRow.leadingWidth + 12,
                  title: kPrivacyPolicy.title,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  chevron: true,
                  onTap: () => Navigator.of(
                    context,
                  ).push(LegalDocScreen.route(kPrivacyPolicy)),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            InsetGroup(
              label: 'Potvrzuji, že',
              horizontalInset: 0,
              children: [
                _Check(
                  value: _recording,
                  onChanged: (v) => setState(() => _recording = v),
                  text:
                      'Budu nahrávat jen se svolením lidí, kteří jsou na '
                      'nahrávce slyšet, a podle pravidel školy.',
                ),
                _Check(
                  value: _ai,
                  onChanged: (v) => setState(() => _ai = v),
                  text:
                      'Rozumím, že zvuk, text a fotky odcházejí do služeb '
                      'AI, jejichž klíče zadám, a že AI se může mýlit.',
                ),
                _Check(
                  value: _age,
                  onChanged: (v) => setState(() => _age = v),
                  text:
                      'Je mi alespoň 15 let, nebo mám souhlas rodiče či '
                      'jiného zákonného zástupce.',
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _ready && !_busy ? _accept : null,
              child: const Text('Souhlasím a pokračovat'),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Souhlasem přijímáš Podmínky použití a Zásady ochrany osobních '
              'údajů (verze $kTermsVersion).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
