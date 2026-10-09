import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accent.dart';
import '../../core/app_route.dart';
import '../../core/logging.dart';
import '../../core/pending_deletions.dart';
import '../../core/search.dart';
import '../../core/spacing.dart';
import '../../core/widgets/count_chip.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/result_transition.dart';
import '../../core/widgets/inset_group.dart';
import '../../data/db/app_database.dart';
import '../../data/search_service.dart';
import '../meeting_detail/meeting_detail_screen.dart';
import '../notes_library/saved_note_screen.dart';
import '../subjects/card_editor_screen.dart';
import '../subjects/subjects_providers.dart';

/// One search field over everything the app has written.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static Route<void> route() =>
      AppRoute<void>(builder: (_) => const SearchScreen());

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
  String _acceptedQuery = '';
  final _seenResults = <String>{};
  bool _busy = false;

  /// Null shows every kind.
  SearchKind? _kind;

  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final recent = await ref
          .read(appDatabaseProvider)
          .preferencesDao
          .recentSearches();
      if (mounted) setState(() => _recent = recent);
    } catch (e, st) {
      AppLog.e('search', 'recent searches not read', e, st);
    }
  }

  /// Remembered once the student acts on a query — submits it or opens a
  /// hit — not on every half-typed word.
  Future<void> _remember() async {
    final query = _controller.text;
    if (searchWords(query).isEmpty) return;
    setState(() => _recent = pushRecentSearch(_recent, query));
    try {
      await ref.read(appDatabaseProvider).preferencesDao.addRecentSearch(query);
    } catch (e, st) {
      AppLog.e('search', 'recent search not stored', e, st);
    }
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const []);
    try {
      await ref.read(appDatabaseProvider).preferencesDao.clearRecentSearches();
    } catch (e, st) {
      AppLog.e('search', 'recent searches not cleared', e, st);
    }
  }

  void _useQuery(String query) {
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _onChanged(query);
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
        _kind = null;
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
      _acceptedQuery = query;
      _busy = false;
      // A filter left on a kind this query has no hits in would show nothing.
      if (_kind != null && !hits.any((h) => h.kind == _kind)) _kind = null;
    });
  }

  Future<void> _open(SearchHit hit) async {
    unawaited(_remember());
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
          CardEditorScreen.route(subjectId: card.subjectId, card: card),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final raw = _hits;
    final hits = raw == null
        ? null
        : visibleHits(
            raw,
            hiddenMeetings: ref.watch(pendingIdsProvider(DeletionKind.meeting)),
            hiddenNotes: ref.watch(pendingIdsProvider(DeletionKind.note)),
            hiddenCards: ref.watch(pendingIdsProvider(DeletionKind.card)),
          );

    final entering = <String>{};
    for (final hit in hits ?? const <SearchHit>[]) {
      final id = _hitKey(hit);
      if (_seenResults.add(id)) entering.add(id);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Gap.lg),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (_) => _remember(),
            decoration: InputDecoration(
              hintText: 'Hledat ve všem',
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Vymazat',
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Gap.md),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Gap.md),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Gap.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: Gap.sm),
            ),
          ),
        ),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: hits == null
          ? _Start(recent: _recent, onQuery: _useQuery, onClear: _clearRecent)
          : hits.isEmpty
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'Nic nenalezeno',
              message: 'Zkus jiné slovo — hledá se na všechna slova zároveň.',
            )
          : _Results(
              revision: (
                _acceptedQuery,
                _kind,
                Object.hashAll(hits.map(_hitKey)),
              ),
              entering: entering,
              hits: hits,
              kind: _kind,
              onKind: (k) => setState(() => _kind = k),
              onTap: _open,
            ),
    );
  }
}

/// Before the first letter: recent searches and the subjects as ready-made
/// queries, so a search can start with a tap.
class _Start extends ConsumerWidget {
  const _Start({
    required this.recent,
    required this.onQuery,
    required this.onClear,
  });

  final List<String> recent;
  final ValueChanged<String> onQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    if (recent.isEmpty && subjects.isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Hledej v hodinách',
        message:
            'Prohledá názvy hodin, přepisy, poznámky, karty i chat. '
            'Na diakritice nezáleží.',
      );
    }
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: EdgeInsets.only(
        top: Gap.sm,
        bottom: Gap.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (recent.isNotEmpty) ...[
          InsetGroup(
            label: 'Nedávná hledání',
            children: [
              for (final q in recent)
                ListRow(
                  leading: Icon(Icons.history, size: 20, color: muted),
                  title: q,
                  chevron: false,
                  trailing: Icon(Icons.north_west, size: 16, color: muted),
                  onTap: () => onQuery(q),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: Gap.lg),
              child: TextButton(
                onPressed: onClear,
                child: const Text('Vymazat historii'),
              ),
            ),
          ),
        ],
        if (subjects.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.xl + Gap.sm,
              Gap.lg,
              Gap.lg,
              Gap.sm,
            ),
            child: Text(
              'PODLE PŘEDMĚTU',
              style: theme.textTheme.labelMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            child: Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final s in subjects)
                  ActionChip(
                    avatar: SubjectDot(
                      color: subjectColor(context, s.subject.colorIndex),
                    ),
                    label: Text(s.subject.name),
                    onPressed: () => onQuery(s.subject.name),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The hits grouped by kind, with a chip row to narrow them to one kind.
class _Results extends StatelessWidget {
  const _Results({
    required this.revision,
    required this.entering,
    required this.hits,
    required this.kind,
    required this.onKind,
    required this.onTap,
  });

  final List<SearchHit> hits;
  final Object revision;
  final Set<String> entering;
  final SearchKind? kind;
  final ValueChanged<SearchKind?> onKind;
  final void Function(SearchHit) onTap;

  static const _slot = 52.0;

  static IconData _icon(SearchKind kind) => switch (kind) {
    SearchKind.lesson => Icons.mic_rounded,
    SearchKind.transcript => Icons.subject_rounded,
    SearchKind.note => Icons.sticky_note_2_rounded,
    SearchKind.card => Icons.style_rounded,
    SearchKind.chat => Icons.chat_bubble_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final groups = <SearchKind, List<SearchHit>>{
      for (final k in SearchKind.values)
        k: hits.where((h) => h.kind == k).toList(growable: false),
    }..removeWhere((_, v) => v.isEmpty);

    return ResultTransition(
      revision: revision,
      child: ListView(
        padding: EdgeInsets.only(
          top: Gap.sm,
          bottom: Gap.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (groups.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Row(
                children: [
                  CountChip(
                    label: 'Vše',
                    count: hits.length,
                    selected: kind == null,
                    onSelected: () => onKind(null),
                  ),
                  for (final e in groups.entries) ...[
                    const SizedBox(width: Gap.sm),
                    CountChip(
                      label: e.key.label,
                      count: e.value.length,
                      selected: kind == e.key,
                      onSelected: () => onKind(e.key),
                    ),
                  ],
                ],
              ),
            ),
          for (final e in groups.entries)
            if (kind == null || kind == e.key)
              InsetGroup(
                label: e.key.label,
                trailingLabel: '${e.value.length}',
                dividerIndent: Gap.lg + _slot,
                children: [
                  for (final hit in e.value)
                    Entrance(
                      key: ValueKey(_hitKey(hit)),
                      enabled: entering.contains(_hitKey(hit)),
                      child: ListRow(
                        leadingSlot: _slot,
                        leading: GradientIconTile(icon: _icon(hit.kind)),
                        title: hit.title,
                        subtitle: hit.subtitle,
                        excerptSpan: hit.excerpt.text.isEmpty
                            ? null
                            : searchExcerptSpan(context, hit.excerpt),
                        onTap: () => onTap(hit),
                      ),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

String _hitKey(SearchHit hit) =>
    '${hit.kind}:${hit.meetingId}:${hit.segmentId}:${hit.noteId}:${hit.cardId}';

/// The excerpt with the matched word marked in the accent, so the eye lands
/// on the reason this row is in the list rather than on its first words.
InlineSpan searchExcerptSpan(BuildContext context, SearchExcerpt excerpt) {
  final text = excerpt.text;
  final end = excerpt.start + excerpt.length;
  final marked = excerpt.length > 0 && excerpt.start >= 0 && end <= text.length;
  if (!marked) return TextSpan(text: text);
  final accent = context.accent;
  return TextSpan(
    children: [
      TextSpan(text: text.substring(0, excerpt.start)),
      TextSpan(
        text: text.substring(excerpt.start, end),
        style: TextStyle(
          color: accent.text,
          fontWeight: FontWeight.w700,
          backgroundColor: accent.text.withValues(alpha: 0.14),
        ),
      ),
      TextSpan(text: text.substring(end)),
    ],
  );
}
