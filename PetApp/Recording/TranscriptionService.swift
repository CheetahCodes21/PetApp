//
//  TranscriptionService.swift
//  PetApp
//
//  Speech-to-text for saved memories (KAN-20). On-device where the device
//  supports it (KAN-38 privacy). Separate from `SpeechService`, which is
//  text-to-speech (reading text aloud).
//

import Speech

enum TranscriptionService {

    enum TranscriptionError: Error { case notAuthorized, unavailable }

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Transcribes an audio file, preferring on-device recognition. Throws if
    /// the user hasn't authorized speech recognition or no recognizer is
    /// available; callers treat that as "save audio-only" (US-016 AC5).
    static func transcribe(url: URL, languageCode: String = "en-US") async throws -> String {
        let current = SFSpeechRecognizer.authorizationStatus()
        let status = current == .notDetermined ? await requestAuthorization() : current
        guard status == .authorized else { throw TranscriptionError.notAuthorized }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode)),
              recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false

        let guardBox = ResumeGuard()
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                // The callback can fire more than once; resume the continuation
                // at most once to avoid a crash.
                if let error {
                    if guardBox.claim() { continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                if guardBox.claim() {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

/// Thread-safe one-shot latch so a continuation is resumed exactly once.
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
