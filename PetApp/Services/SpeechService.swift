//
//  SpeechService.swift
//  PetApp
//
//  Thin wrapper over AVSpeechSynthesizer for the text-to-voice feature,
//  used to preview the chosen voice speed during onboarding/settings.
//

import AVFoundation

@MainActor
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// Speaks `text` at the given normalized speed (0...1) in the given language.
    func speak(_ text: String, speed: Double, languageCode: String = "en") {
        let utterance = AVSpeechUtterance(string: text)

        // Map 0...1 onto a comfortable, intelligible band rather than the
        // full min/max range (which is too slow / too fast at the extremes).
        let low = AVSpeechUtteranceMinimumSpeechRate
        let high = AVSpeechUtteranceDefaultSpeechRate
        let clamped = max(0, min(1, speed))
        utterance.rate = low + (high - low) * Float(clamped)

        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")

        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
