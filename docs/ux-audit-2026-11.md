# UX audit — November 2026

Date: 2026-11-18. Build: `main` at `97b7713` (1.0.0+3).
Goal: make Aftermind easier to use for a student in class — fewer steps,
fewer errors, clearer screens. No new features.

## How it was tested

- Read the README, `docs/` (pilot quality pass, study flow, alive motion) and
  the last 30 commits, so this pass builds on M54–M61 and the October pilot
  pass instead of redoing them.
- Ran the real screens through the web preview
  (`flutter build web -t lib/preview/main_web_preview.dart`, synthetic demo
  data, fake keys, no network, no microphone) in a browser at 360 × 780 and
  1280 × 800, light and dark. Scenarios: `?scenario=fresh` (first launch) and
  `?scenario=full` (returning student).
- The web build cannot record, play local audio or call AI services. Those
  paths were read in code (`recording_controller.dart`,
  `transcription_queue_worker.dart`, `transcription_wait_notice.dart`,
  `transcript_segment_tile.dart`, settings) instead of being run.
  Phone calls, screen lock and route changes still need the device checks
  listed in `docs/pilot-quality-pass.md`.

Screenshots: `docs/screenshots/ux-2026-11/audit/`.

## Journeys walked

| Journey | Steps today | Notes |
| --- | --- | --- |
| First launch → consent | 4 taps (3 checkboxes + continue) | Legally required; clear. Kept. |
| Onboarding → working transcription key | 6 actions: tap „Připoj přepis" → scroll past the colour picker → tap field → paste → Uložit → Ověřit klíč | „Uložit" always says „Klíč uložen." even for a wrong key; the check is a separate button that appears only after saving. ([01](screenshots/ux-2026-11/audit/01-home-first-launch.png), [02](screenshots/ux-2026-11/audit/02-settings-from-onboarding.png)) |
| Start recording | 2 taps (record → Začít), subject pre-selected from the timetable | Good. Chips in the sheet are 35 px tall. ([04](screenshots/ux-2026-11/audit/04-new-recording-sheet.png)) |
| During recording | — | The disabled player „Přehrávání bude dostupné po ukončení nahrávání" sits above the transcript for the whole lesson. „Odpověz teď" / „Důležité" are 38 px tall. ([05](screenshots/ux-2026-11/audit/05-recording.png)) |
| Stop recording | 2 taps (stop → Ukončit) + clear saved message | Good. ([06](screenshots/ux-2026-11/audit/06-stop-confirm.png), [07](screenshots/ux-2026-11/audit/07-after-stop.png)) |
| While transcribing | — | Pending rows say „Čeká na přepis…"; the notice explains limits and a missing key and links to Settings. Failed chunks each need their own 32 px „Zkusit znovu". |
| Read notes (returning) | 1 tap from Dnes („Poslední výpisky") | Opens on Výpisky (pilot pass). The first line of notes starts at y ≈ 415 of 780: app bar, player, subject bar, „Upravit výpisky" and the toolbar come first. ([09](screenshots/ux-2026-11/audit/09-notes-dark.png)) |
| Quiz | notes → „Vyzkoušet se před testem" → Připravit test | Topic of the lesson you came from is not pre-selected. ([10](screenshots/ux-2026-11/audit/10-exam-prep.png)) |
| Ask about a lesson | chat bar on Přepis | Works; hint text changes from „Kontext, otázka nebo pravidlo…" (live) to „Zeptej se na přepis…" (after). |
| Library: rename / delete | long-press row → sheet → action | Delete has undo. Texts still say „schůzka" (meeting). |
| Error states | — | No key: notice + link to Settings (good). Rate limit: says when it resumes (good). Wrong key: only discovered when chunks fail. |

## Friction points (all found)

Each has evidence; „copy" items are judged as a native Czech reader.

1. **Saving a key never checks it.** `settings_screen.dart` `_save()` stores the
   key and shows „Klíč uložen." regardless of whether it works. A typo or an
   expired key is found only during the next lesson, when every chunk fails.
   „Ověřit klíč" is a separate, optional button.
2. **Key setup opens Settings at the colour picker.** The onboarding step
   „Připoj přepis" pushes `SettingsScreen`, whose first section is „Vzhled";
   the Groq field starts below it ([02](screenshots/ux-2026-11/audit/02-settings-from-onboarding.png)).
   The screen never says where a free key comes from (Gemini: „Klíč zdarma
   dostaneš v Google AI Studiu", without a link; Groq: nothing).
3. **The audio player takes the top of the lesson screen in every state.**
   During recording it is disabled with „Přehrávání bude dostupné po ukončení
   nahrávání." On the Výpisky tab it pushes the notes down by ~95 px; the
   first note line starts at y ≈ 415 on a 780 px screen.
4. **Failed transcript chunks are retried one by one.** Each failed row has its
   own small (32 px) „Zkusit znovu"; a lesson with many parked chunks (e.g.
   after a refused key) needs one tap per chunk, and the row never says what
   to do if retrying does not help.
5. **Old „schůzka" wording in a school app.** „Přejmenovat schůzku", „Smazat
   schůzku", „Nahrávanou schůzku nejde smazat", „Schůzku se nepodařilo
   smazat", „Poznámky ze schůzky", save-note sheet text.
6. **Library empty state points at a tab that does not exist.**
   `notes_library_screen.dart`: „…v záložce Poznámky je vytvoř…" — the tab is
   called „Výpisky".
7. **Czech plural bug.** „Přepis čeká na zpracování $pending úseků" reads
   „1 úseků", „2 úseků", „3 úseků".
8. **Touch targets under 44 px.** Subject and card chips in „Nové nahrávání"
   (35 px), „Odpověz teď" / „Důležité" (38 px), topic chip (31 px), failed-row
   retry (32 px).
9. **Quiz from a lesson ignores the lesson.** „Vyzkoušet se před testem" under
   a lesson's notes opens the subject quiz with no topic selected.
10. **Repeated text on the notes tab.** The AI disclaimer appears twice (under
    the notes and under „Učení"); the depth label „Vyvážené" appears twice
    („Upravit výpisky · Vyvážené" and again beside the toolbar).
11. **Live-answer toggle on finished lessons.** The lightbulb in the app bar
    flips a *global* setting; on a past lesson it does nothing visible and its
    only label is a tooltip.
12. **Settings is one 17-section scroll.** Keys, appearance, profile,
    reminders, storage, sync, sensitivity and rules share one list.
13. **Wide screens.** At 1280 px notes and lists stretch edge to edge; lines
    run ~150 characters ([11](screenshots/ux-2026-11/audit/11-notes-desktop.png)).
    iPhone is the target, so low impact.
14. **Screen-reader semantics of notes.** In the web build note bullets are
    exposed as disabled text fields. Needs a VoiceOver check on a device
    before changing anything.
15. **Web page title** is „recorder" before Flutter starts (web only).

## Top 10, ranked by impact ÷ effort

| # | Item | Impact | Effort | Plan |
| --- | --- | --- | --- | --- |
| 1 | Check the key when it is saved (1) | High: catches the most damaging setup error before class | S | Phase 2 |
| 2 | Key setup lands on the key, with a link to get one (2) | High for first launch | S | Phase 2 (same PR as 1) |
| 3 | Lesson screen: player only where it helps (3) | High: every lesson read and every recording | S | Phase 2 |
| 4 | School wording, wrong tab name, plural (5, 6, 7) | Medium: confusing copy on common screens | S | Phase 2 |
| 5 | Retry all failed chunks in one tap (4) | High when it happens | M | Phase 2 |
| 6 | 44 px touch targets in class controls (8) | Medium | S | Next |
| 7 | Quiz pre-selects the lesson's topic (9) | Medium | S | Next |
| 8 | Remove repeated disclaimer and depth label (10) | Low–medium | S | Next |
| 9 | Live-answer toggle only while recording (11) | Low | S | Next |
| 10 | Group Settings (keys first, the rest folded) (12) | Medium | L | Later |

Not ranked: wide-screen max width (13, M, low impact), notes semantics (14,
needs a device), web title (15, web only).
