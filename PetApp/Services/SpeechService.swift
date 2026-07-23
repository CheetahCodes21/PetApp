//
//  SpeechService.swift
//  PetApp
//
//  Text-to-voice for the voice-speed preview and the daily-question read-aloud.
//
//  Two tiers, best first:
//   1. A pre-rendered, high-quality cloud-TTS clip for the exact text, if one
//      was generated and bundled (see VoiceClips / Tools/generate-voices.py).
//      This gives a consistent, on-theme voice regardless of the device.
//   2. On-device `AVSpeechSynthesizer`, tuned to the friendliest installed
//      voice for the language, as a universal fallback.
//

import AVFoundation

@MainActor
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var clipPlayer: AVAudioPlayer?

    /// Pitch of the voice. 1.0 is the voice's natural pitch. A big lift makes a
    /// compact voice sound tinny/robotic, so we keep it near neutral and rely on
    /// picking a genuinely nice, high-quality female voice instead. Valid
    /// range 0.5...2.0 — nudge up very slightly (e.g. 1.1) for a touch more warmth.
    private let voicePitch: Float = 1.0

    /// Preferred voice names, best first. These are Apple's warmer, natural
    /// English female voices; the highest-quality installed match wins.
    private let preferredVoiceNames = ["Ava", "Samantha", "Allison", "Susan", "Karen", "Serena", "Zoe"]

    private init() {}

    /// Speaks `text`: plays the pre-rendered clip when one exists, otherwise
    /// synthesizes on-device at the given normalized speed (0...1) and language.
    func speak(_ text: String, speed: Double, languageCode: String = "en") {
        stop()

        if let url = VoiceClips.clipURL(for: text), playClip(at: url) {
            return
        }

        let utterance = AVSpeechUtterance(string: text)

        // Map 0...1 onto a comfortable, intelligible band rather than the
        // full min/max range (which is too slow / too fast at the extremes).
        let low = AVSpeechUtteranceMinimumSpeechRate
        let high = AVSpeechUtteranceDefaultSpeechRate
        let clamped = max(0, min(1, speed))
        utterance.rate = low + (high - low) * Float(clamped)

        utterance.pitchMultiplier = voicePitch
        utterance.voice = friendlyVoice(for: languageCode)

        synthesizer.speak(utterance)
    }

    /// Speaks `englishText` in the app's selected `language`: uses the language's
    /// translation and matching voice when one exists, otherwise reads the
    /// English text with an English voice (never English words in a foreign
    /// accent). This is the read-aloud entry point callers should use.
    func speakLocalized(_ englishText: String, language: AppLanguage, speed: Double) {
        let resolved = language.spoken(englishText)
        speak(resolved.text, speed: speed, languageCode: resolved.voiceLanguage)
    }

    /// Plays a bundled clip through the speaker. Returns false if it couldn't be
    /// loaded, so the caller can fall back to on-device speech.
    private func playClip(at url: URL) -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            clipPlayer = player
            player.play()
            return true
        } catch {
            return false
        }
    }

    /// Picks the nicest installed voice for `languageCode`, scoring each so a
    /// female voice is strongly preferred, then higher audio quality (premium /
    /// enhanced sound far warmer than the compact default), then a known warm
    /// name. Falls back to the system default so speech always works.
    private func friendlyVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(languageCode) }

        guard let best = candidates.max(by: { score($0) < score($1) }) else {
            return AVSpeechSynthesisVoice(language: languageCode)
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        return best
    }

    /// Higher is better. Female dominates, then quality, then a warm name.
    private func score(_ voice: AVSpeechSynthesisVoice) -> Int {
        var value = 0
        if voice.gender == .female { value += 1_000 }
        value += voice.quality.rawValue * 100   // premium(3) / enhanced(2) / default(1)
        if let index = preferredVoiceNames.firstIndex(of: voice.name) {
            value += preferredVoiceNames.count - index
        }
        return value
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        clipPlayer?.stop()
        clipPlayer = nil
    }
}
