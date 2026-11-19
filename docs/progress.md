# Progress log

Append only. Newest entry at the bottom.

## 2026-11-19 — UX pass for students in class (1.0.1)

**What.** An audit of the main journeys (`docs/ux-audit-2026-11.md`) and the
five highest-value small fixes from it, merged as #2–#5 and released as
1.0.1 (build 4):

1. Saving a Groq or Gemini key checks it at once and says whether it works,
   was refused, or cannot be checked offline / over a limit (#2).
2. Key setup from onboarding, the no-key sheet and the missing-key notice
   opens Settings with the cursor in the key field; keys come before
   appearance; a „Získat klíč zdarma" link sits on each empty key card (#2).
3. The lesson screen hides the audio player while any lesson records and on
   the notes tab until playback is started (#3).
4. School wording instead of leftover „schůzka", the library empty state
   names the real „Výpisky" tab, correct Czech counts (#4).
5. One „Zkusit znovu vše" for failed transcript chunks; retry moves only
   parked chunks (#5).

**Why.** A student in class has seconds, not minutes. The audit found that a
wrong key surfaced only in the next lesson, key setup started at the colour
picker, notes began halfway down the screen, failed chunks needed one tap
each, and several texts named things that do not exist.

**Numbers** (360 × 780, web preview with demo data):

| Journey | Before | After |
| --- | --- | --- |
| Onboarding → checked transcription key | 6 actions | 3 (tap step, paste, Uložit) |
| Read notes: first note line | y ≈ 415 | y ≈ 318; all four sections on one screen |
| Recover N failed chunks | N taps | 1 tap |
| Wrong key detected | during the next lesson | on Save |

The recording screen also lost its disabled player row.

Tests: 7 new or extended test files (key check, lesson screen, wording guard,
wait notice, queue worker, default titles, queue DAO on an in-memory drift
database). `flutter analyze` clean; iOS CI green on every PR branch.

**What worked.** The existing web preview (`lib/preview/main_web_preview.dart`)
made a real walk-through possible without keys or a microphone; stubbing the
new key check there kept it offline. Writing the widget test against the real
`MeetingDetailScreen` with an in-memory drift database caught both the
intended failure and a teardown hang (pending timers) early. Independent
reviews found real issues in #2 (any 400/401/403 called a bad key; Gemini
card stayed red after a good check) and #5 (retry could reset an upload in
flight).

**Watch out.** Some files use CRLF or even mixed endings (`meeting_detail_screen.dart`,
`transcription_queue_worker.dart`, several tests); edit them byte-preserving.
The iOS workflow runs only on pushes to main; run it on a PR branch with
`gh workflow run ios.yml --ref <branch>`.

**Next ideas.**
- 44 px touch targets for the in-class controls (subject chips 35 px,
  „Odpověz teď"/„Důležité" 38 px, topic chip 31 px).
- „Vyzkoušet se před testem" from a lesson pre-selects that lesson's topic.
- Remove the repeated AI disclaimer and „Vyvážené" label on the notes tab.
- Show the live-answers toggle only while recording.
- Group Settings: keys first, the rest folded into sections.
- Device checks still open from `docs/pilot-quality-pass.md` (calls, screen
  lock, VoiceOver on notes).
