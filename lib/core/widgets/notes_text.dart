import 'package:flutter/material.dart';

import '../spacing.dart';

/// Generated notes, laid out.
///
/// The prompts produce plain text — `- ` bullets, short heading lines ending in
/// a colon, blank lines between blocks — and it stays plain text on purpose, so
/// the copy button hands over something that pastes cleanly anywhere. Rendering
/// it verbatim in a single `Text` is what made it read badly: a wrapped bullet
/// came back to the left margin and the list stopped looking like a list.
///
/// Flutter cannot hang-indent inside one text run, so each block is its own
/// widget. The cost is that a drag-selection stops at a block boundary; the
/// copy button next to it covers "give me all of it", which is what people
/// actually want from notes.
///
/// Shared by the meeting's notes tab and the saved-notes library, so a note
/// looks the same before and after it is saved.
class NotesText extends StatelessWidget {
  const NotesText({super.key, required this.content});

  final String content;

  /// The bullet's own text, or null if the line is not a bullet. Models are
  /// inconsistent about which mark they use even when the prompt says `- `.
  static final _bullet = RegExp(r'^\s*[-•*–]\s+(.*)$');

  /// A short line ending in a colon is one of the prompts' section headings
  /// (`Rozhodnutí:`, `Úkoly:`). The length cap keeps an ordinary sentence that
  /// happens to end in a colon from being promoted to a heading.
  static bool _isHeading(String line) =>
      line.endsWith(':') && line.length <= 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.45);

    final blocks = <Widget>[];
    var gap = false;

    void add(Widget block) {
      if (gap && blocks.isNotEmpty) {
        blocks.add(const SizedBox(height: Gap.md));
      }
      gap = false;
      blocks.add(block);
    }

    for (final raw in content.trim().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        gap = true;
        continue;
      }

      final bullet = _bullet.firstMatch(line)?.group(1)?.trim();
      if (bullet != null && bullet.isNotEmpty) {
        add(
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A real bullet glyph rather than the model's hyphen, in a
                // fixed-width box so every line of text starts on the same
                // column no matter how the marks differ.
                SizedBox(
                  width: Gap.lg,
                  child: Text(
                    '•',
                    style: body?.copyWith(color: scheme.outline),
                  ),
                ),
                Expanded(child: SelectableText(bullet, style: body)),
              ],
            ),
          ),
        );
        continue;
      }

      if (_isHeading(line)) {
        add(
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
            child: Text(
              line,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
        );
        continue;
      }

      add(
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.xs),
          child: SelectableText(line, style: body),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}
