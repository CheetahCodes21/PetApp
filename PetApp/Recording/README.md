# Recording (Dev 3 / Audio) — full flow

This branch is stacked on `feature/kan-19-audio-recording-v2` and adds everything
after capture: **complete and save a memory** (KAN-20), **voice-data privacy**
(KAN-38), and **attach a photo** (KAN-21). The recording UI (KAN-19 / KAN-35) and
the microphone path (KAN-8) live on the branch below — see its README for capture
details.

**Do not rebuild recording or save UI in the main screen** — trigger it with the
two modifiers below.

## The whole feature in two modifiers (for Dev 2)

The main screen owns the layout and the Record button:

```swift
struct MainPetScreen: View {
    @State private var showRecording = false
    let currentQuestion: String?

    var body: some View {
        VStack {
            // ... pet, feed button, question, etc. (Dev 2) ...
            Button("Record") { showRecording = true }   // your styled button
        }
        // Record → (save sheet) → SavedMemory:
        .memoryRecorder(isPresented: $showRecording, question: currentQuestion) { memory in
            // `memory` is a SavedMemory. Route to the memory screen (Dev 4),
            // and optionally react (e.g. bump the streak).
        }
        // Offer back an interrupted recording on next launch (add once):
        .recordingRecovery { memory in /* route the recovered, saved memory */ }
    }
}
```

`onSaved` fires when the user taps **Save** in the completion sheet. Everything
inside — permission prompt, level meter, limits, pause/resume, phone-call
handling, "start over", assembling segments, on-device transcription, photo
attach, privacy disclosure, the auto-dismissing "Saved" confirmation — is handled
here.

## What the save flow does (KAN-20)

On finishing a recording, `SaveMemoryView` presents: title (required, with a
prefilled suggestion), audio playback with scrubbing, an editable transcript that
fills in when speech-to-text finishes, add-photo, a date, and Cancel / Save.

- **Transcription** is on-device where supported (`TranscriptionService`). If the
  user saves *before* it finishes, the memory is saved immediately and the
  transcript is attached to the stored memory when ready (US-016 AC4) — a detached
  task survives the sheet dismissing.
- If transcription fails, the memory saves **audio-only** with a `.failed`
  transcript state; Dev 4's memory-detail screen offers "Try again" (US-016 AC5).
- Cancel / close always **confirms** before discarding (US-016 AC7).
- Saving shows an **auto-dismissing "Saved" confirmation + haptic**, then returns
  to the host (US-016 AC6). The inline toast can be replaced by Dev 5's shared
  `ToastView` (KAN-41) when available.

## Privacy of voice data (KAN-38)

- A plain-language `PrivacyDisclosureView` is shown **once before the first
  transcription**, stating that audio is turned into text **on-device** and stored
  **encrypted**. Acknowledgement is remembered (`@AppStorage voicePrivacyAcknowledged`).
- Recordings and memories are **encrypted at rest** (file protection on the
  Recordings and Memories directories). Processing is on-device, so nothing is in
  transit.
- **Dev 5 — please link to this from Settings** so it's reachable any time
  (US-034 AC4). Show it read-only with a Done button:
  ```swift
  PrivacyDisclosureView(onAcknowledge: nil)   // read-only, Done button
  ```

## Attach a photo (KAN-21)

`PhotoAttachmentView` (in the save sheet): choose from library (PhotosPicker, no
prompt) or take a photo (camera, gated via the shared `PermissionsManager`). If
the camera is denied, an inline route to Settings is shown; camera is hidden on
devices without one. One photo per memory, replaceable/removable before saving;
editing the photo **after** saving is Dev 4's memory-detail screen (KAN-25).
Stored as compressed JPEG.

## Hand-off to Dev 4 (memory screen) — the contract

Dev 4 owns the archive and memory-detail screens and their `Memory` model. This
flow currently writes a **stubbed `SavedMemory`** (`SavedMemory.swift`) via a stub
`MemoryStore`. When Dev 4's `Memory` / `MemoryRepository` land, the save flow
writes through the repository instead and this stub is deleted. Fields a `Memory`
needs:

| Field            | Source                          |
| ---------------- | ------------------------------- |
| audio file URL   | assembled from draft segments   |
| duration         | `RecordingDraft.duration`       |
| created date     | save-sheet date field           |
| question text    | `RecordingDraft.questionText`   |
| transcript       | on-device speech-to-text        |
| transcript state | `.ready` / `.pending` / `.failed` / `.none` |
| photo (optional) | photo attachment (compressed)   |

Dev 4 also owns: the "Try again" transcript retry on the detail screen, and
editing/replacing the photo after saving.

## TEMP scaffolding — do not build on top of it

`ContentView` carries **clearly-marked TEMP** pieces so the flow is testable
before Dev 2's home screen and Dev 4's memory screen exist:

- A **"Record a memory"** button in `HomePlaceholderView` — stands in for Dev 2's
  Record button. **Delete when Dev 2's real button lands.**
- `MemoryDestinationPlaceholder` — stands in for Dev 4's memory screen; only shows
  the saved memory's fields to prove the handoff. **Delete when Dev 4's screen
  lands.**
- `SavedMemory` / `MemoryStore` — stub persistence. **Replace with Dev 4's
  `Memory` / `MemoryRepository`, then delete.**

Please **do not add new screens here** — the real screens are owned by Dev 2 / 4.

## ⚠️ Manual step — speech-recognition usage description

`NSSpeechRecognitionUsageDescription` must be set in the target build settings
(**Target → Build Settings → "Privacy - Speech Recognition Usage Description"**),
value e.g. *"MemoMe transcribes your recordings so you can read and search them."*
Without it the app **crashes** the first time it requests speech-recognition
permission. (It couldn't be committed via tooling because editing the Xcode
project file while Xcode is open risks crashing Xcode.) Recording still works
without it; only transcription is affected.

## Notes / dependencies

- **Info.plist keys:** `NSMicrophoneUsageDescription` (KAN-19, on `main`),
  `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` (KAN-21, on
  `main`), `NSSpeechRecognitionUsageDescription` (KAN-20, see manual step above).
- **Capture code** (AudioRecorder, DraftStore, RecordingView, …) is owned by the
  KAN-19 branch below and is not modified here — this branch only extends
  `RecordingIntegration` and the `ContentView` handoff, so the two branches don't
  conflict.
