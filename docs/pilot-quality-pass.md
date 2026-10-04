# Aftermind pilot quality pass — 2026-10-04

## Scope and evidence

The product remains a Czech school assistant. This pass improves the existing
find lesson → record → save → listen → read notes flow, without a new AI provider,
database migration, payment module, or change of brand.

The visual review used the real Flutter screens with isolated synthetic records
in `lib/preview/main_web_preview.dart`. It did not open the user's recordings or
send their transcripts to a service. A populated preview is not evidence that the
user's installed iPhone database has been opened successfully.

## Five concrete weaknesses and changes

| Before | After |
| --- | --- |
| At 390 × 844 the recording hero occupied roughly 420 px; saved lessons started near the bottom navigation. | The idle hero ends around 281 px; both synthetic saved lessons are visible without scrolling. Study reminders follow the recording list. |
| The latest-notes row opened the transcript. Notes controls occupied the first part of the detail. | The row opens the notes tab; regeneration options collapse when notes already exist. School lessons use the label `Výpisky`. |
| There was no player for the original locally stored recording. | A lazily loaded chunk playlist provides play/pause, seeking and retry on supported native platforms. Missing/empty files or timeline gaps produce an explicit error, not a silently shortened recording. |
| Stop returned before the final audio chunk finished persisting; there was no reliable saved confirmation. | A saving state disables controls. Stop awaits local writes before marking the lesson ended. Failed persistence keeps the recovery checkpoint and marks the lesson interrupted; success and failure get distinct messages. |
| A global wait could label a completed lesson as waiting; narrow notices clipped. Gemini-only users were told they still needed Groq. | Waiting is scoped to the open lesson, wraps on narrow screens, and missing credentials link to Settings. Either supported transcription key satisfies onboarding. |

Playback has its own player per mounted detail. Starting capture blocks further
playback, waits for in-flight player preparation, and pauses existing players
before opening the microphone. This ordering is tested separately from the
native plugins; iOS audio-session interaction still requires a device test.

The second review also found a control-row overflow at 180% text scaling.
Captions now stay within their action's width and wrap instead of forcing the
whole row off-screen. All four dashboard states (idle, recording, paused, saving)
pass at 320 × 640. Cleared audio no longer leaves a retry button or seek slider,
and a player already open is stopped when its lesson's audio is cleared.

## Data safeguards

- No database reset, schema change, recording-path migration, or sample-data
  replacement was performed. Existing device data was not installed over.
- Failure tests write disposable synthetic PCM/WAV and SQLite files in temporary
  directories, never the application's real documents directory.
- Playback only reads local audio. It does not start transcription or upload it.
- No real recordings, transcripts, screenshots, keys, or private database copies
  are included in the commit. `tool/.pillow/` was present before the work and is
  deliberately excluded.
- A verified backup of the user's actual device data has **not** been made here.
  Make and verify a recoverable backup before installing on that device. This is
  a prerequisite, not a claim that an export or Git preserves audio.

## Verification boundaries

Automated checks cover final-tail persistence, reopening a synthetic disk-backed
database with its WAV intact, failed-write recovery, pause handling, playback
timeline boundaries, missing files, playback/capture ordering, narrow waiting
notices, and the existing queue/detection/notes regressions.

Current local results:

- `flutter analyze`: no issues.
- `flutter build apk --debug`: successful for the final source; not installed.
- Synthetic web preview: release build succeeded; reviewed in light/dark at
  390 × 844. The later small-screen control fixes were verified by widget tests,
  not by claiming a further successful browser session.
- The final full serial regression completed with 1,052 passes and one suite
  loading failure: `playback_files_test.dart` reported `Connection closed before
  test suite loaded`. Its six cases then passed in a separate run. This is not
  reported as a single all-green full-suite invocation.
- All four dashboard cases passed after correcting the fixture and the layout
  overflow revealed by large text.
- The final focused run passed 69 cases; an existing microphone-watchdog case
  did not complete in that combined run. Re-running the recording-controller
  file separately passed all 10 cases, including that watchdog case.

The tests use controlled audio, storage, HTTP responses and connectivity; they
do not establish live cloud transcription quality or decode WAV through a real
iPhone audio session. A flaky old 40 ms queue test now controls its timer rather
than assuming the host finishes its assertions before a wall-clock deadline.

The synthetic browser review confirmed the compact dashboard in light/dark
themes and the latest-notes navigation with readable output. Further browser
checks encountered repeated control timeouts; a complete visual small-screen,
large-text and keyboard review cannot be claimed from those attempts.

An Android debug build is a compile/package check, not a successful microphone
or playback run. No physical Android or iPhone was connected. The attempted
read-only Android emulator did not remain online. No app was installed onto
the user's existing device during this pass.

## Required before an external pilot

1. Back up the original device data and verify restoration on a separate copy.
2. Build and install the updated iOS app; test local WAV playback and seeking
   across chunk boundaries, then playback → capture → playback repeatedly.
3. With synthetic audio, verify microphone permission denial/grant, pause/resume,
   stop/save, app restart, screen lock/background and a phone interruption.
4. Disconnect the network: preserve audio, show honest waiting, restore the
   connection and verify one transcript/output without duplicated processing.
5. Run a small-display/large-text/VoiceOver and keyboard review on the device.
   Confirm the saved lesson and notes are still reachable and controls usable.
6. Only after these checks, give a small consenting group the app and measure
   whether they can find a lesson and obtain useful notes without assistance.

Passing automated tests does not establish recording quality in a classroom,
safe iOS background operation, willingness to pay, or readiness for sale.
