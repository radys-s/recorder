import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/spacing.dart';
import '../../legal/data_processors.dart';

/// „Co se posílá a podmínky" under a service's key: opens what goes to the
/// service, any training warning, and links to its own terms.
class DataProcessorNotice extends StatelessWidget {
  const DataProcessorNotice(this.processor, {super.key});

  final DataProcessor processor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: () => showDataProcessorSheet(context, processor),
        icon: const Icon(Icons.info_outline, size: 18),
        label: const Text('Co se posílá a podmínky služby'),
      ),
    );
  }
}

Future<void> showDataProcessorSheet(
  BuildContext context,
  DataProcessor processor,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: DataProcessorDetails(processor),
      ),
    ),
  );
}

/// What goes to [processor] and where its rules are.
class DataProcessorDetails extends StatelessWidget {
  const DataProcessorDetails(this.processor, {super.key});

  final DataProcessor processor;

  Future<void> _open(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Odkaz se nepodařilo otevřít: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final training = processor.training;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(processor.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: Gap.md),
        Text('Co se posílá', style: theme.textTheme.titleSmall),
        const SizedBox(height: Gap.xs),
        Text(processor.sent, style: theme.textTheme.bodyMedium),
        if (training != null) ...[
          const SizedBox(height: Gap.md),
          Text('Trénink a lidská kontrola', style: theme.textTheme.titleSmall),
          const SizedBox(height: Gap.xs),
          Text(training, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: Gap.md),
        Text(
          'Na zpracování se vztahují podmínky služby. Aplikace posílá data '
          'jen tehdy, když je klíč vyplněný.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          children: [
            if (processor.termsUrl case final url?)
              OutlinedButton(
                onPressed: () => _open(context, url),
                child: const Text('Podmínky'),
              ),
            if (processor.privacyUrl case final url?)
              OutlinedButton(
                onPressed: () => _open(context, url),
                child: const Text('Ochrana údajů'),
              ),
          ],
        ),
      ],
    );
  }
}
