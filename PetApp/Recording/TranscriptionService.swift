//
//  TranscriptionService.swift
//  PetApp
//
//  Speech-to-text for saved memories (KAN-20). Prefers private on-device
//  recognition, and falls back to Apple's speech service when the device or
//  language can't transcribe on-device (see the privacy disclosure / policy).
//  Separate from `SpeechService`, which is text-to-speech (reading aloud).
//

import Speech
import os

enum TranscriptionService {

    enum TranscriptionError: Error { case notAuthorized, unavailable }

    private static let log = Logger(subsystem: "com.AppleFoundationProgram.PetApp",
                                    category: "Transcription")

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Transcribes an audio file in the given language. Prefers private,
    /// on-device recognition, and falls back to Apple's speech servers only
    /// when the device/locale can't recognize on-device (e.g. the Simulator, or
    /// a locale without the dictation model) — so a transcript is still
    /// produced. Throws if the user hasn't authorized speech recognition or no
    /// recognizer exists for the language; callers treat that as "save
    /// audio-only" (US-016 AC5).
    static func transcribe(url: URL, languageCode: String = "en-US") async throws -> String {
        let current = SFSpeechRecognizer.authorizationStatus()
        let status = current == .notDetermined ? await requestAuthorization() : current
        log.info("Auth status: \(status.rawValue, privacy: .public)")
        guard status == .authorized else { throw TranscriptionError.notAuthorized }

        // Build a recognizer for the requested language, falling back to the
        // device's current locale and then US English so we don't dead-end on
        // an unsupported identifier.
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
            ?? SFSpeechRecognizer()
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer else {
            log.error("No SFSpeechRecognizer for \(languageCode, privacy: .public) or fallbacks")
            throw TranscriptionError.unavailable
        }
        log.info("Recognizer locale=\(recognizer.locale.identifier, privacy: .public) available=\(recognizer.isAvailable, privacy: .public) supportsOnDevice=\(recognizer.supportsOnDeviceRecognition, privacy: .public)")

        // Try on-device first when supported (private), then fall back to the
        // server. If that order fails, try the other mode too — some devices
        // succeed one way but not the other.
        let preferOnDevice = recognizer.supportsOnDeviceRecognition
        do {
            return try await recognize(url: url, recognizer: recognizer, onDevice: preferOnDevice)
        } catch {
            log.error("First attempt (onDevice=\(preferOnDevice, privacy: .public)) failed: \(error.localizedDescription, privacy: .public); retrying opposite mode")
            return try await recognize(url: url, recognizer: recognizer, onDevice: !preferOnDevice)
        }
    }

    /// One recognition pass with a fixed on-device/server mode.
    private static func recognize(url: URL,
                                  recognizer: SFSpeechRecognizer,
                                  onDevice: Bool) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = onDevice
        request.shouldReportPartialResults = false

        let guardBox = ResumeGuard()
        // Hold the recognizer and task strongly until recognition finishes —
        // if either is released early the task is cancelled and no result
        // arrives (a common cause of "nothing gets transcribed").
        let holder = TaskHolder()
        return try await withCheckedThrowingContinuation { continuation in
            holder.task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    Self.log.error("Recognition failed (onDevice=\(onDevice, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                    if guardBox.claim() { continuation.resume(throwing: error) }
                    holder.retain(recognizer)   // keep alive until we've resumed
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                Self.log.info("Transcription finished, \(text.count, privacy: .public) chars")
                if guardBox.claim() { continuation.resume(returning: text) }
                holder.retain(recognizer)
            }
        }
    }
}

/// Keeps the recognizer and its task alive for the lifetime of the async call.
private final class TaskHolder: @unchecked Sendable {
    var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    func retain(_ recognizer: SFSpeechRecognizer) { self.recognizer = recognizer }
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
