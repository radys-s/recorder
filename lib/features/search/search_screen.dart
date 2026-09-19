import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/search.dart';
import '../../core/spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/pressable.dart';
import '../../data/db/app_database.dart';
import '../../data/search_service.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../notes_library/saved_note_screen.dart';
import '../subjects/card_editor_screen.dart';

/// One search field over everything the app has written.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SearchScreen());

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  Timer? _debounce;

  /// Rises with every query started, so a slow search that finished after a
  /// newer one cannot overwrite the newer results.
  int _run = 0;

  List<SearchHit>? _hits;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Whatever is still running answers a query that is no longer in the
    // field — clearing it must not bring the old results back.
    _run++;
    if (searchWords(value).isEmpty) {
      setState(() {
        _hits = null;
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    // Typing is faster than reading a whole meeting's transcripts; searching on
    // every keystroke would run the corpus several times per word.
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
  }

  Future<void> _search(String query) async {
    final run = ++_run;
    List<SearchHit> hits;
    try {
      hits = await SearchService(ref.read(appDatabaseProvider)).search(query);
    } catch (e, st) {
      AppLog.e('search', 'search failed', e, st);
      hits = const [];
    }
    if (!mounted || run != _run) return;
    setState(() {
      _hits = hits;
      _busy = false;
    });
  }

  Future<void> _open(SearchHit hit) async {
    final navigator = Navigator.of(context);
    switch (hit.kind) {
      case SearchKind.lesson:
      case SearchKind.chat:
      case SearchKind.transcript:
        final id = hit.meetingId;
        if (id == null) return;
        await navigator.push(
          MeetingDetailScreen.route(id, focusSegmentId: hit.segmentId),
        );
      case SearchKind.note:
        final id = hit.noteId;
        if (id == null) return;
        await navigator.push(SavedNoteScreen.route(id));
      case SearchKind.card:
        final id = hit.cardId;
        if (id == null) return;
        final card = await ref.read(appDatabaseProvider).subjectsDao.card(id);
        if (card == null || !mounted) return;
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CardEditorScreen(subjectId: card.subjectId, card: card),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hits = _hits;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Hledat ve všem',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Vymazat',
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: hits == null
          ? const EmptyState(
              icon: Icons.search,
              title: 'Hledej v hodinách',
              message:
                  'Prohledá názvy hodin, přepisy, poznámky, karty i chat. '
                  'Na diakritice nezáleží.',
            )
          : hits.isEmpty
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'Nic nenalezeno',
              message: 'Zkus jiné slovo — hledá se na všechna slova zároveň.',
            )
          : _Results(hits: hits, onTap: _open),
    );
  }
}

/// The hits grouped by kind, each group under its own heading.
class _Results extends StatelessWidget {
  const _Results({required this.hits, required this.onTap});

  final List<SearchHit> hits;
  final void Function(SearchHit) onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[];
    for (final kind in SearchKind.values) {
      final group = hits.where((h) => h.kind == kind).toList(growable: false);
      if (group.isEmpty) continue;
      rows
        ..add(kind)
        ..addAll(group);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        if (row is SearchKind) {
          return Padding(
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm),
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        return _HitTile(hit: row as SearchHit, onTap: () => onTap(row));
      },
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = hit.subtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Pressable(
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(width: Gap.sm),
                        Text(
                          subtitle,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hit.excerpt.text.isNotEmpty) ...[
                    const SizedBox(height: Gap.xs),
                    _Excerpt(excerpt: hit.excerpt),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The excerpt with the matched word marked, so the eye lands on the reason
/// this row is in the list rather than on its first three words.
class _Excerpt extends StatelessWidget {
  const _Excerpt({required this.excerpt});

  final SearchExcerpt excerpt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final text = excerpt.text;
    final end = excerpt.start + excerpt.length;
    final marked =
        excerpt.length > 0 && excerpt.start >= 0 && end <= text.length;

    return Text.rich(
      TextSpan(
        children: marked
            ? [
                TextSpan(text: text.substring(0, excerpt.start)),
                TextSpan(
                  text: text.substring(excerpt.start, end),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    backgroundColor: scheme.secondaryContainer,
                  ),
                ),
                TextSpan(text: text.substring(end)),
              ]
            : [TextSpan(text: text)],
      ),
      style: base,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
