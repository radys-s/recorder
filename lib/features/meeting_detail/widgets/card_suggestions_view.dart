import 'package:flutter/material.dart';

import '../../../ai/card_suggestions.dart';
import '../../../core/motion.dart';
import '../../../core/spacing.dart';
import '../../../core/widgets/pressable.dart';

/// Reconciles stored suggestions; outgoing rows cannot be tapped or announced.
class CardSuggestionsView extends StatefulWidget {
  const CardSuggestionsView({
    super.key,
    required this.suggestions,
    required this.onAdd,
    required this.onDismiss,
  });
  final List<CardSuggestion> suggestions;
  final Future<void> Function(CardSuggestion) onAdd;
  final Future<void> Function(CardSuggestion) onDismiss;
  @override
  State<CardSuggestionsView> createState() => _CardSuggestionsViewState();
}

class _CardSuggestionsViewState extends State<CardSuggestionsView> {
  final _listKey = GlobalKey<AnimatedListState>();
  late final _items = [...widget.suggestions];
  final _settled = <CardSuggestion>{};
  bool _pending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) _settled.addAll(_items);
  }

  @override
  void didUpdateWidget(CardSuggestionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final duration = reducedMotion(context) ? Duration.zero : AppDuration.quick;
    _settled.retainAll(widget.suggestions);
    for (var i = _items.length - 1; i >= 0; i--) {
      if (widget.suggestions.contains(_items[i])) continue;
      final removed = _items.removeAt(i);
      var hidden = reducedMotion(context);
      _listKey.currentState?.removeItem(i, (context, animation) {
        hidden = hidden || reducedMotion(context);
        return hidden
            ? const SizedBox.shrink()
            : ExcludeSemantics(
                child: IgnorePointer(
                  child: SizeTransition(
                    sizeFactor: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: _row(removed, enabled: false),
                    ),
                  ),
                ),
              );
      }, duration: duration);
    }
    for (var i = 0; i < widget.suggestions.length; i++) {
      final item = widget.suggestions[i];
      if (i < _items.length && _items[i] == item) continue;
      final old = _items.indexOf(item);
      if (old >= 0) {
        _items.removeAt(old);
        _listKey.currentState?.removeItem(
          old,
          (_, _) => const SizedBox(),
          duration: Duration.zero,
        );
      }
      _items.insert(i, item);
      _listKey.currentState?.insertItem(i, duration: duration);
    }
  }

  Future<void> _act(CardSuggestion item, bool add) async {
    if (_pending) return;
    setState(() => _pending = true);
    try {
      await (add ? widget.onAdd(item) : widget.onDismiss(item));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kartu se nepodařilo uložit nebo skrýt. Zkus to znovu.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Widget _row(CardSuggestion item, {bool enabled = true}) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey(item),
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: Gap.xs),
            Text(
              item.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: Gap.sm,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Nechci',
                  onPressed: enabled && !_pending
                      ? () => _act(item, false)
                      : null,
                ),
                Pressable(
                  child: FilledButton.tonal(
                    onPressed: enabled && !_pending
                        ? () => _act(item, true)
                        : null,
                    child: const Text('Přidat'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_items.isNotEmpty) ...[
        const SizedBox(height: Gap.xl),
        Text(
          'Uložit jako kartu',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Gap.sm),
      ],
      AnimatedList(
        key: _listKey,
        initialItemCount: _items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i, animation) =>
            reducedMotion(context) || _settled.contains(_items[i])
            ? _row(_items[i])
            : SizeTransition(sizeFactor: animation, child: _row(_items[i])),
      ),
    ],
  );
}
