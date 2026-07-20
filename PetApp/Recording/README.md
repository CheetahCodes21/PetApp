# Recording (Dev 3 / Audio) — capture + crash recovery

This branch delivers **audio capture** (KAN-19), **never-lose-a-recording**
(KAN-35), and the **microphone permission path** (KAN-8). It is self-contained:
the recording UI (level meter, timer, pause/resume, start-over, crash recovery)
is owned here. Other screens only *trigger* it — **do not rebuild recording UI
in the main screen.**

> The follow-up branch (KAN-20, "complete and save a memory") layers the
> completion sheet — title, transcript, photo, save — on top of this. It extends
> `RecordingIntegration` and does **not** modify the capture code. See the
> boundary note at the end.

## What this branch produces

Capturing a recording yields a `RecordingDraft` (see `RecordingModels.swift`):
an id, created date, duration, the ordered audio segment file names on disk, and
the answered question. Load a segment with `DraftStore.shared.segmentURL(named:)`.

Saving a draft as a real *memory* (assembling the audio, transcript, photo) is
**not** in this branch — it arrives with KAN-20. Here, keeping a recording hands
the raw `RecordingDraft` back to the caller.

## For Dev 2 — add recording to the main screen

The main screen owns the layout and the Record button. Wire recording in with
one state flag and two modifiers:

```swift
struct MainPetScreen: View {
    @State private var showRecording = false
    let currentQuestion: String?   // the random journalling question, if any

    var body: some View {
        VStack {
            // ... pet, feed button, question, etc. (Dev 2) ...
            Button("Record") { showRecording = true }   // your styled button
        }
        // Recording flow — presented as a full-screen cover:
        .memoryRecorder(isPresented: $showRecording, question: currentQuestion) { draft in
            // `draft` is a RecordingDraft. On the KAN-20 branch this callback
            // becomes the saved-memory handoff instead.
        }
        // Offer back an interrupted recording on next launch (add once):
        .recordingRecovery { draft in /* keep / route the recovered draft */ }
    }
}
```

Everything inside the cover — permission prompt, level meter, 10s–20min limits,
pause/resume, phone-call handling, "start over" confirmation — is handled here.
Recording **starts automatically** when the cover appears, so the user only taps
once.

## Microphone permission (KAN-8)

The mic path is owned here (the permission *screen shell* in onboarding is
Dev 1's). If the user has denied the microphone, tapping Record shows a plain
explanation with a **single "Open Settings" button** — no other UI, no dead-end.
The mic usage description is set in the target build settings
(`INFOPLIST_KEY_NSMicrophoneUsageDescription`), already present on `main`.

## Limits (team decision)

10 seconds minimum, **20 minutes maximum** (not 30) — a deliberate team decision
for this audience. A warning appears two minutes before the end and recording
stops automatically at the limit, preserving everything captured. If the backlog
still says 30 min, that AC should be updated to match this decision.

## Hand-off to Dev 4 (memory screen)

Dev 4 owns the archive and memory-detail screens and their `Memory` model. Dev 4
does **not** read `RecordingDraft` directly. On the KAN-20 branch, the save flow
turns a draft into a saved memory using Dev 4's model, then navigates to Dev 4's
screen. The fields a `Memory` needs from a recording:

| Field            | Source                        | Branch |
| ---------------- | ----------------------------- | ------ |
| audio file URL   | assembled from draft segments | KAN-20 |
| duration         | `RecordingDraft.duration`     | KAN-19 |
| created date     | `RecordingDraft.createdAt`    | KAN-19 |
| question text    | `RecordingDraft.questionText` | KAN-19 |
| transcript       | speech-to-text on save        | KAN-20 |
| photo (optional) | photo attachment              | KAN-21 |

**Action:** Dev 3 + Dev 4 confirm this field list on the `Memory` type before
KAN-20 merges.

## For Dev 5 (widgets) / Dev 2 (unwell → record) — programmatic entry

Use the `RecordingCoordinator` contract in `RecordingModels.swift`. The real
implementation lands with the save-memory flow (KAN-20); until then use
`MockRecordingCoordinator`, which returns a fixed sample draft.

## TEMP scaffolding — do not build on top of it

To exercise this flow before Dev 2's home screen and Dev 4's memory screen
exist, `ContentView` carries **clearly-marked TEMP** pieces:

- A **"Record a memory"** button in `HomePlaceholderView` — stands in for Dev 2's
  Record button. **Delete when Dev 2's real button lands.**
- `MemoryDestinationPlaceholder` — stands in for Dev 4's memory screen; only
  proves the handoff. **Delete when Dev 4's screen lands.**

These are intentionally minimal so they don't collide with Dev 2 / Dev 4 work.
**Please do not add new screens here** — the real screens are owned elsewhere.

## Boundary note (for the KAN-20 branch)

`RecordingView` exposes `onFinish: (RecordingDraft) -> Void` and knows nothing
about saving. The save sheet is presented by `RecordingIntegration`, so KAN-20
extends only that file (and swaps the `ContentView` handoff), leaving the capture
code untouched. Keep it that way to avoid merge conflicts across the two branches.

## Notes / dependencies

- **Info.plist:** `NSMicrophoneUsageDescription` — recording (in build settings,
  already on `main`).
- **Draft model:** `RecordingModels.swift`. Drafts persist under Application
  Support/`Recordings`, encrypted at rest (file protection), and are recovered on
  next launch until the user explicitly acts on them.
