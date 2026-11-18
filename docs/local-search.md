# Finding a saved lesson and topic locally

Date: 2026-10-07. Builds on study flow commit `c2bd091`; does not replace it.

## Scope and behavior

- The dashboard's existing search and the Library's new search action open the
  same `SearchScreen`. The Library's smaller saved-note filter remains available.
- The existing matcher searches lesson titles, subject names, live/refined
  transcripts, **lesson notes not yet saved to the Library**, saved notes,
  context cards and chat. Every query word must match, without case/diacritics.
  Words can occur in different fields of the same document.
- Subject filters use IDs, not name queries. The start screen's subject chips
  also select this filter. Period: last 7 calendar days, last 30, or an inclusive
  custom date range. All filters can be cleared without clearing the query.
- Lesson-derived results use the lesson date; saved notes and context cards use
  their update date. Filtering happens **before** result limits.
- Results identify their source, subject/date and a highlighted text excerpt.
  Start at 25 matches per source, newest first; "Zobrazit další výsledky" expands
  that limit. Transcripts retain the existing maximum of 3 excerpts per lesson.
  Nonempty refined text takes precedence over the live chunks it covers.
- A lesson-note hit opens the lesson's notes tab. Transcript/chat/title hits
  open its transcript tab; live transcript hits keep the existing segment focus.
  Saved notes and context cards retain their existing detail/editor destinations.
- Query, filters and scroll controller stay mounted under detail routes. Returning
  refreshes data without discarding the query or scroll position.
- An empty library, no matching results, and a failed DB query have distinct
  messages. Errors offer a retry and are logged internally, not shown as zero hits.

## Data and performance

No schema changes, extra database, provider, network request, or AI processing.
`SearchService` still reads the existing Drift tables. A lightweight `SELECT 1`
subscription declares its table dependencies to receive invalidations, without
subscribing to all corpus rows. The screen debounces changes and runs at most one
corpus scan at once; superseded results cannot overwrite the current query.
Pending deletions remain hidden through the existing deletion providers; a DB
deletion refreshes results, and opening checks that the parent record still exists.
Saved notes remain independent snapshots when their source lesson is deleted.

On native platforms `compute` handles normalization, matching, sorting and excerpt
creation off the UI isolate. Corpus records are read on demand and held in memory
for one search; this is not a disk-backed index. On web `compute` runs inline.
Large-corpus memory usage and physical-phone latency have **not** been benchmarked.

## Files

- `lib/core/search.dart`: source kind, subject/date filter and hit metadata.
- `lib/data/search_service.dart`: local corpus, invalidations and worker matching.
- `lib/features/search/search_screen.dart`: filtering, states, navigation and position.
- `lib/features/notes_library/notes_library_screen.dart`: shared search entry point.
- `test/search_test.dart`, `test/search_screen_test.dart`: focused synthetic checks.

Recording, backup and lesson-detail work already dirty in the checkout is outside
this commit. See [the existing study flow](study-flow.md) for learning actions.

## Verification

Commands for this phase:

```text
flutter analyze --no-pub
flutter test --no-pub -j 1 test/search_test.dart test/search_screen_test.dart --reporter expanded
flutter build apk --debug --no-pub
```

The focused tests cover unsaved lesson notes, subject/text matching, filters before
limits, filter-only browsing, loading more, deletions, a synthetic missing-table
failure, and query/scroll preservation after returning from a saved note. Existing
matching, refinement precedence, kind filtering and recent-search checks remain.
No full regression campaign, manual phone session, original-data access or install
is part of this phase. Android build includes the preserved working-tree changes;
it is not an isolated artifact of this search commit. iOS is not built locally.
