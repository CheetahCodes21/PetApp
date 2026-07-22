# Voice clips — pre-rendered read-aloud

The daily-question read-aloud prefers a **pre-rendered, high-quality cloud-TTS
clip** for each question, falling back to on-device `AVSpeechSynthesizer` when no
clip exists. This gives a consistent, on-theme voice on every device, instead of
whatever system voice happens to be installed.

## How it fits together

- `PetApp/PetApp/Services/DailyPrompts.swift` — the question set (source of truth).
- `Tools/voice-manifest.json` — the exact spoken lines to render. **Must match
  DailyPrompts byte-for-byte** (the clip is looked up by SHA-256 of the text).
- `Tools/generate-voices.py` — renders each line to `<key>.mp3` via ElevenLabs
  (stdlib only, no pip install).
- `PetApp/PetApp/Services/VoiceClips.swift` — computes the same key and finds the
  bundled clip; `SpeechService` plays it or falls back to on-device speech.

`key = first 16 hex chars of SHA-256(spokenText)` — identical in the script and
the app, so file names line up automatically.

## Generating the clips

1. Get an ElevenLabs API key and pick a voice (a warm, friendly, slightly playful
   female voice suits the companion). Copy its **Voice ID**.
2. Run:
   ```sh
   ELEVENLABS_API_KEY=sk_... ELEVENLABS_VOICE_ID=<voiceId> python3 Tools/generate-voices.py
   ```
   Clips land in `PetApp/PetApp/Voices/`. Re-running skips lines already rendered.
3. In Xcode, add the `Voices` folder to the **PetApp target** (drag it in; either
   a folder reference or a group works). Build — read-aloud now uses the clips.

## When you change a question

1. Edit `DailyPrompts.swift`.
2. Mirror the exact new wording into `Tools/voice-manifest.json`.
3. Re-run the script (old, unused clips can be deleted; new ones are generated).

## Localization

On `feature/recording-improvements` the manifest is **English only**. On the
localization branch, add the translated lines to the manifest (each language's
string hashes to its own clip) and re-run, so read-aloud speaks the selected
language in the same nice voice.
