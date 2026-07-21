//
//  AudioSessionController.swift
//  PetApp
//
//  Owns the shared audio session for recording and reports system
//  interruptions (phone calls, alarms, Siri) so the recorder can pause and
//  offer to resume (US-015 AC4). Kept separate from the recorder so the widget
//  and unwell-companion flows can reuse the same session policy.
//

import AVFoundation

@MainActor
final class AudioSessionController {

    /// Called when the system interrupts recording (for example, a call starts).
    var onInterruptionBegan: (() -> Void)?
    /// Called when the interruption ends; `shouldResume` is the system's hint
    /// that resuming audio is appropriate.
    var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)?

    private var interruptionObserver: NSObjectProtocol?

    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.allowBluetoothHFP, .defaultToSpeaker])
        try session.setActive(true)
        installObserverIfNeeded()
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - Microphone permission

    var permissionStatus: AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Interruption observation

    private func installObserverIfNeeded() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                self?.handleInterruption(note)
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            onInterruptionBegan?()
        case .ended:
            var shouldResume = false
            if let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                shouldResume = options.contains(.shouldResume)
            }
            onInterruptionEnded?(shouldResume)
        @unknown default:
            break
        }
    }
}
