#!/usr/bin/env python3
#
# generate-voices.py
#
# Pre-renders the fixed question set to high-quality audio clips using
# ElevenLabs, so the app's read-aloud sounds consistent and on-theme on every
# device. Each line is saved as <key>.mp3 where key = first 16 hex chars of
# SHA-256(text) — the SAME key VoiceClips.key(for:) computes in the app, so the
# bundled file is found at runtime. Stdlib only, no pip install needed.
#
# Usage:
#   ELEVENLABS_API_KEY=sk_... \
#   ELEVENLABS_VOICE_ID=<voiceId> \
#   python3 Tools/generate-voices.py
#
# Optional env:
#   ELEVENLABS_MODEL   (default: eleven_multilingual_v2)
#   VOICES_OUT_DIR     (default: ../PetApp/Voices relative to this script)
#
# After it runs, add the PetApp/Voices folder to the app target in Xcode
# (folder reference or group — both are handled by VoiceClips.clipURL). Re-run
# whenever you change a question; it skips lines whose clip already exists.

import os
import sys
import json
import hashlib
import pathlib
import urllib.request
import urllib.error

API_KEY = os.environ.get("ELEVENLABS_API_KEY")
VOICE_ID = os.environ.get("ELEVENLABS_VOICE_ID")
MODEL = os.environ.get("ELEVENLABS_MODEL", "eleven_multilingual_v2")

if not API_KEY or not VOICE_ID:
    sys.exit("Set ELEVENLABS_API_KEY and ELEVENLABS_VOICE_ID. See the header of this file.")

here = pathlib.Path(__file__).resolve().parent
manifest = json.loads((here / "voice-manifest.json").read_text(encoding="utf-8"))
out_dir = pathlib.Path(os.environ.get("VOICES_OUT_DIR", here.parent / "PetApp" / "Voices"))
out_dir.mkdir(parents=True, exist_ok=True)


def key(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


written = skipped = 0
for text in manifest.get("lines", []):
    clip = out_dir / f"{key(text)}.mp3"
    if clip.exists():
        print(f"skip  {key(text)}  {text}")
        skipped += 1
        continue

    body = json.dumps({
        "text": text,
        "model_id": MODEL,
        # Tune for a warm, friendly, slightly playful companion read.
        "voice_settings": {"stability": 0.45, "similarity_boost": 0.8, "style": 0.35, "use_speaker_boost": True},
    }).encode("utf-8")

    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}?output_format=mp3_44100_128",
        data=body,
        method="POST",
        headers={"xi-api-key": API_KEY, "content-type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            clip.write_bytes(resp.read())
    except urllib.error.HTTPError as err:
        sys.exit(f"FAIL  {err.code}  {text}\n{err.read().decode(errors='replace')}")

    print(f"write {key(text)}  {text}")
    written += 1

print(f"\nDone. {written} written, {skipped} skipped, into {out_dir}")
