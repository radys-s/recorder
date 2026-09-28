import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/spacing.dart';
import '../../core/widgets/inset_group.dart';
import '../../legal/legal_texts.dart';
import 'legal_doc_screen.dart';

/// Settings › O aplikaci: version, the legal texts, licences and the AI
/// disclaimer.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AboutScreen());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('O aplikaci')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          Text('Aftermind', style: theme.textTheme.headlineSmall),
          const SizedBox(height: Gap.xs),
          Text('Verze $kAppVersion', style: muted),
          const SizedBox(height: Gap.md),
          Text(
            'Nahrávání hodin, přepis a výpisky s pomocí AI. Bez serveru, '
            'bez účtu, bez reklam a bez analytiky — data zůstávají '
            'v telefonu.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Gap.xl),
          InsetGroup(
            dividerIndent: ListRow.textIndent + 12,
            horizontalInset: 0,
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
              ListRow(
                leadingSlot: ListRow.leadingWidth + 12,
                title: 'Licence open-source knihoven',
                leading: const Icon(Icons.article_outlined),
                chevron: true,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Aftermind',
                  applicationVersion: kAppVersion,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          Text('Umělá inteligence', style: theme.textTheme.titleSmall),
          const SizedBox(height: Gap.xs),
          Text(kAiDisclaimer, style: muted),
        ],
      ),
    );
  }
}
