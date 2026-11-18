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

## Gates recorded on 2026-10-04 (superseded by the current closure below)

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

## Quality closure after M61a–M61d — 2026-10-06

Baseline inspected: `5795e6e`, following `9003c4a` and M61a–M61d. The initial
worktree contained only untracked `tool/.pillow/`, which was preserved. No device
database was opened, no update installed, and no user media processed or shared.
There is no schema migration: the application remains at schema 27.

### Current evidence matrix

“Verified” below means the named local check, not a claim of iPhone proof.

| Open point | Current status | Evidence / boundary |
| --- | --- | --- |
| Stop, final chunk and save confirmation | Fixed and verified with synthetic capture/storage | Controller tests wait for the tail WAV and queue row; reopen disk-backed SQLite; preserve recovery on write failure. Stop now also waits for a microphone restart already in flight. |
| Segment saved but absent from the processing queue | Fixed and verified | Segment + queue insert is one transaction; an injected queue failure leaves neither an orphan segment nor a falsely successful save. |
| Recovery snapshot racing stop | Fixed; ordering inspected, existing recovery tests rerun | A skipped timer tick no longer replaces the actual in-flight checkpoint write with a completed no-op. Native I/O timing still needs the device scenario. |
| Playback boundaries and capture switching | Implemented; mapping/file/ordering tests verified | Continuous playlist, exact boundary seeks, missing files and pending preparation are tested. Actual audio decoding, session switching and phone interruption remain unverified. |
| Restart and offline retry without duplicates | Verified in synthetic SQLite/HTTP/connectivity tests | Disk-backed reopen and queue retry/recovery cases run in the complete suite. No real provider outage or phone restart is claimed. |
| M61 duplicate/late chat replies | Fixed and verified | Simultaneous asks reserve one message before DB awaits. A completion after the watchdog expires cannot replace a successful retry or start a new fallback. |
| Text export confused with a backup | Fixed; archive creation and offline restoration verified | Text export explicitly excludes audio. A separate ZIP snapshots SQLite, includes recordings/photos/cards/checkpoints, verifies SHA-256 + DB integrity + referenced assets, trial-restores before publication, and rejects existing destinations. |
| Small display, large text, keyboard, error recovery | Concrete failures fixed and verified | 320×640 / 200% tests cover the whole detail, chat, outdated/failed notes, backup labels, short loading/error/empty states. Keyboard state is passed above Scaffold's consumed insets; reduced-motion sizing bypasses AnimatedSize. |
| Actual user's device backup and database | Still missing | The new archive was tested only with synthetic files. No original iPhone was connected or updated. |
| Microphone, permissions, background, interruption and iOS playback | Implemented without current physical verification | ADB reported no connected devices. Windows cannot locally build/run the iOS app; no cloud workflow was dispatched. |

### Safety and recovery procedure

The new action is Settings → Soukromí a data → **Záloha včetně zvuku**. Finish
recording and saving first. It creates a consistent `VACUUM INTO` snapshot,
rewrites paths only in that copy, sanitizes stored error columns, and leaves
credentials out. Compression/checksums/trial restoration run off the UI isolate.
Missing referenced media aborts the backup; intentionally cleared audio stays
cleared. The archive is **not encrypted** and contains private lesson material:
save it to a trusted private location outside the phone, never Git/public storage.
A share-sheet success alone is not proof that the external copy is recoverable.

On a computer, restore a copied ZIP into a **new, nonexistent** directory:

```powershell
dart run tool/restore_backup.dart PRIVATE_BACKUP.zip NEW_EMPTY_PATH
```

The tool checks paths, declared/decompressed lengths, duplicate names, checksums,
SQLite integrity and media references. It does not start Aftermind, use keys,
send any lesson to AI, overwrite the installed app, or import data into an iPhone.
Windows/native Dart is covered; returning this copy into a signed iOS app is a
separate physical-device gate. Keep the original archive and previous app build.

**Bootstrap restriction:** the old installed app only has text export. Do not
install this update over the original iPhone merely to obtain the new ZIP action.
First make an independently recoverable device/app-data backup outside the phone
and verify restoration on a separate copy/device, including its original audio.
If this cannot be demonstrated, leave that installation untouched and use a
separate synthetic test installation. No backup of the original phone is claimed.

### Test-run investigation

Today's complete serial baseline passed **1,194 tests**, including loading
`playback_files_test.dart` and the original watchdog case. The historic loader
failure and watchdog hang did not reproduce in that invocation; their exact
historic cause is therefore **unknown**, not retroactively “fixed” by a rerun.
The watchdog test now supplies a clock explicitly instead of sleeping through
real periodic timers. A new test holds a restart open while stop waits for it.

A concurrent focused Flutter command failed before loading because the other
Flutter process held `build/native_assets/windows/sqlite3.dll`. That is a separate
reproduced tooling failure; checks are now sequential. A successful focused run
is not substituted for the final full invocation. The new layout tests also
reproduced real overflow, a zero-duration AnimatedSize layout assertion, and a
ListTile trailing action consuming the entire width; the fixtures were not
weakened to hide these problems.

The synthetic backup was created, trial-restored, reopened through Drift and
restored by the standalone CLI. Its WAV, transcript, notes, photo and recovery
checkpoint survive; original paths/queue remain unchanged. This proves file and
database recovery, not native playback of that WAV.

### Five remaining gates before pilot

1. **Protect the original iPhone:** independently back up and verify recovery of
   its existing DB + audio + notes before any update; retain the previous IPA.
2. **Build/install iOS only on a protected test installation:** verify microphone
   denial/grant, pause/resume, final-tail save, restart, lock/background and an
   interruption. Check playback/seeking across chunk boundaries and repeated
   playback → capture → playback. This pass builds Android, not an IPA.
3. **Run the real offline/provider flow using synthetic speech:** no network for
   one chunk, honest waiting, reconnection/retry, exactly one transcript per
   sequence and one usable set of notes. Check a quota/error message and retry
   without discarding the previous notes. No bulk processing of old lessons.
4. **Review the phone at its smallest supported display / largest text / VoiceOver:**
   navigate dashboard → saved lesson → player/transcript/notes; open/dismiss the
   keyboard, send once, reach retry, and reopen the lesson after app restart.
5. **Three-user unaided pilot only after 1–4:** consenting new users complete the
   short scenario below. Do not infer classroom value or sale readiness from
   automated checks. No invitations, distribution or publishing was performed.

### Physical-device script (synthetic material only)

- Use a separate lesson and known harmless speech for 90 seconds. Include a
  distinctive final three-second phrase immediately before Stop. Deny permission
  once, grant it explicitly, record, pause ten seconds, resume, then stop. Wait
  for saved confirmation; do not navigate away while saving.
- Replay the last phrase and seek through each chunk boundary; pause playback,
  start another short recording, stop it, and return to the first recording.
  Restart the app and confirm both lesson/audio/notes can still be found.
- Repeat with screen lock/background and one phone interruption. A gap must be
  explained rather than disguised as uninterrupted capture. A fake stream or
  web preview does not count as this check.
- Repeat offline for one chunk, reconnect, and confirm recovery without repeated
  passages. Generate notes only for this synthetic lesson; on a service failure,
  confirm an understandable retry and retained previous output.
- Create the private full ZIP, copy outside the phone, restore to an isolated
  directory with the CLI, and compare the final WAV and notes before upgrading
  any installation containing valuable recordings.

### Three-user pilot scenario (not started here)

Give each new user an isolated installation and a 2–3 minute harmless sample
lesson. Ask only: **“Record this lesson, finish and save it, leave the screen,
find it again, replay the end, and obtain notes.”** Provide no navigation hints.
Observe where they hesitate, whether they understand saving/processing states,
and whether they can find the correct lesson and explain its main takeaway.
Record completion or the exact blocking step for each of the three people; do
not count a coached completion as unaided success. Ask what the notes got wrong
and whether they would choose this flow over their current method.
