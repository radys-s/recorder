import 'package:flutter/material.dart';

import '../../core/spacing.dart';
import '../../legal/legal_texts.dart';

/// A full legal text, readable and selectable.
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.doc});

  final LegalDoc doc;

  static Route<void> route(LegalDoc doc) =>
      MaterialPageRoute<void>(builder: (_) => LegalDocScreen(doc: doc));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SafeArea(
        top: false,
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [LegalText(doc.body)],
          ),
        ),
      ),
    );
  }
}

/// Renders the plain format of [LegalDoc.body]: `## ` headings, `- ` bullets
/// with hanging indents, other lines as muted paragraphs.
class LegalText extends StatelessWidget {
  const LegalText(this.body, {super.key});

  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme.bodyLarge?.copyWith(height: 1.45);
    final children = <Widget>[];
    for (final line in body.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('## ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.sm),
            child: Semantics(
              header: true,
              child: Text(t.substring(3), style: theme.textTheme.titleMedium),
            ),
          ),
        );
      } else if (t.startsWith('- ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 20, child: Text('•', style: text)),
                Expanded(child: Text(t.substring(2), style: text)),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Text(
              t,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
