//
//  VoiceClips.swift
//  PetApp
//
//  Looks up pre-rendered, high-quality voice clips for the fixed question set.
//  The clips are generated offline by a cloud TTS (see Tools/generate-voices.py)
//  and bundled under `Voices/`. When a clip exists for the exact spoken text it
//  is played instead of on-device speech; otherwise the caller falls back to
//  `AVSpeechSynthesizer`. This is why the app still works for any text — new or
//  untranslated questions simply have no clip yet.
//

import Foundation
import CryptoKit

enum VoiceClips {

    /// Stable file-name key for a spoken line: the first 16 hex characters of the
    /// SHA-256 of the exact UTF-8 text. The generation script computes the
    /// identical key, so the bundled file name matches at runtime. Keying on the
    /// spoken text (not an id) means it works uniformly for anchors, follow-ups,
    /// reflections, and every language — the localized string hashes to its own
    /// clip.
    static func key(for spokenText: String) -> String {
        let digest = SHA256.hash(data: Data(spokenText.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    /// The bundled clip URL for `spokenText`, or nil if none was generated.
    /// Accepts either `.mp3` (ElevenLabs' default) or `.m4a`, and whether the
    /// `Voices` folder was added as a folder reference or a flat group.
    static func clipURL(for spokenText: String) -> URL? {
        let name = key(for: spokenText)
        for ext in ["mp3", "m4a"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Voices")
                ?? Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
