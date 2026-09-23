import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ai/answer_source.dart';
import '../../../core/logging.dart';
import '../../../core/spacing.dart';

/// The pages a web-backed answer came from, as tappable domain chips.
///
/// A source that cannot be opened is decoration, and decoration that looks
/// like evidence is worse than no evidence at all — that is the whole reason
/// these are links rather than a line of grey text under the answer.
class AnswerSources extends StatelessWidget {
  const AnswerSources({super.key, required this.sources});

  final List<AnswerSource> sources;

  static const _tag = 'ui.answers.sources';

  Future<void> _open(BuildContext context, AnswerSource source) async {
    // The system browser, not an in-app view: a search result is untrusted
    // content, and it has no business rendering inside the app that is holding
    // the meeting's recording.
    var opened = false;
    try {
      opened = await launchUrl(
        source.url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e, st) {
      AppLog.e(_tag, 'could not open ${source.url}', e, st);
    }

    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Odkaz se nepodařilo otevřít: ${source.url}')),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Wrap(
        spacing: Gap.xs + 2,
        runSpacing: Gap.xs + 2,
        children: [
          for (final source in sources)
            Material(
              color: scheme.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(Gap.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(Gap.sm),
                onTap: () => _open(context, source),
                // The full title in the tooltip: the chip says which site, the
                // tooltip says which page.
                child: Tooltip(
                  message: source.title,
                  child: Semantics(
                    button: true,
                    label: 'Otevřít zdroj ${source.title}, ${source.domain}',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.sm,
                          vertical: Gap.xs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: foreground,
                            ),
                            const SizedBox(width: Gap.xs),
                            Text(
                              source.domain,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
