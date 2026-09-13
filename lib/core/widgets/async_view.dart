import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../spacing.dart';

/// Renders an [AsyncValue]'s loading and error states so screens only have to
/// write the one case that matters.
///
/// Every `.when(...)` site used to interpolate the raw exception into Czech
/// copy — `'Seznam se nepodařilo načíst: $e'` — which puts a `DioException`
/// toString in front of someone who wanted to read their meeting notes. Here
/// the user gets a sentence and a way out, and the technical detail is kept
/// where it is useful: a debug build.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.message,
    required this.builder,
    this.onRetry,
  });

  final AsyncValue<T> value;

  /// What went wrong, in the user's terms. A whole sentence, no exception.
  final String message;

  final Widget Function(T data) builder;

  /// Omitted where there is nothing to retry — a drift stream re-emits on its
  /// own, so most call sites pass a `ref.invalidate`.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // hasValue first, so a stream that is refreshing keeps showing what it
    // already has instead of blanking to a spinner.
    if (value.hasValue) return builder(value.requireValue);
    if (value.hasError) {
      return _AsyncError(
        message: message,
        error: value.error!,
        onRetry: onRetry,
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}

class _AsyncError extends StatelessWidget {
  const _AsyncError({
    required this.message,
    required this.error,
    this.onRetry,
  });

  final String message;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Gap.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Gap.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Zkusit znovu'),
              ),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: Gap.lg),
              _DebugDetail(error: error),
            ],
          ],
        ),
      ),
    );
  }
}

/// Collapsed by default even in debug, so the exception is one tap away
/// without dominating the screen it appears on.
class _DebugDetail extends StatelessWidget {
  const _DebugDetail({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'Detail (debug)',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        children: [
          SelectableText(
            error.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
