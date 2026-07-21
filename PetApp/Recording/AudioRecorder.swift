//
//  AudioRecorder.swift
//  PetApp
//
//  The core audio recorder (KAN-19 "Record my answer" + KAN-35 "Never lose a
//  recording"). Records to disk continuously as AAC segments, supports pause /
//  resume, survives interruptions such as phone calls, enforces the 10s–20min
//  limits, and keeps an always-current draft on disk for crash recovery.
//

import AVFoundation
import Combine
import SwiftUI

@MainActor
final class AudioRecorder: NSObject, ObservableObject {

    // MARK: - Published state (drives the UI)

    @Published private(set) var phase: RecorderPhase = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    /// Normalised input level 0...1 for the live meter.
    @Published private(set) var level: Float = 0
    /// True once within two minutes of the maximum length.
    @Published private(set) var isApproachingLimit = false
    @Published var errorMessage: String?
    /// True when the microphone permission is denied (KAN-8). Drives a dedicated
    /// explanation with a single route to Settings, not a generic error banner.
    @Published private(set) var micPermissionDenied = false

    // MARK: - Collaborators

    private let store = DraftStore.shared
    private let session = AudioSessionController()

    private var recorder: AVAudioRecorder?
    private var draft: RecordingDraft?
    /// Duration accumulated from completed segments (excludes the live one).
    private var priorSegmentsDuration: TimeInterval = 0
    private var meterTimer: Timer?
    private var lastPersistedElapsed: TimeInterval = 0

    var currentDraft: RecordingDraft? { draft }

    override init() {
        super.init()
        session.onInterruptionBegan = { [weak self] in self?.handleInterruptionBegan() }
        session.onInterruptionEnded = { [weak self] resume in
            self?.handleInterruptionEnded(shouldResume: resume)
        }
    }

    // MARK: - Start / resume-recovered

    func start(question: String? = nil) async {
        guard phase == .idle || phase == .finished else { return }
        phase = .preparing
        errorMessage = nil
        micPermissionDenied = false

        guard await ensurePermission() else {
            // KAN-8: show a dedicated mic-permission explanation with a single
            // route to Settings, rather than a generic error.
            micPermissionDenied = true
            phase = .idle
            return
        }
        guard store.hasRoomToRecord() else {
            fail("There isn't enough space to record right now. Please free up some space and try again.")
            return
        }
        do {
            try session.activate()
        } catch {
            fail("We couldn't start recording. Please try again.")
            return
        }

        let newDraft = RecordingDraft(questionText: question)
        draft = newDraft
        priorSegmentsDuration = 0
        elapsed = 0
        lastPersistedElapsed = 0
        isApproachingLimit = false
        store.save(newDraft)

        if beginNewSegment() {
            startMeterTimer()
            phase = .recording
        }
    }

    /// Continues a recovered draft by appending a fresh segment to it.
    func resumeRecovered(_ recovered: RecordingDraft) async {
        micPermissionDenied = false
        guard await ensurePermission() else {
            micPermissionDenied = true
            return
        }
        do {
            try session.activate()
        } catch {
            errorMessage = "We couldn't continue recording. Please try again."
            return
        }
        draft = recovered
        priorSegmentsDuration = recovered.duration
        elapsed = recovered.duration
        lastPersistedElapsed = recovered.duration
        isApproachingLimit = elapsed >= RecordingLimits.warningThreshold

        if beginNewSegment() {
            startMeterTimer()
            phase = .recording
        }
    }

    // MARK: - Pause / resume

    func pause() {
        guard phase == .recording else { return }
        recorder?.pause()
        stopMeterTimer()
        persistProgress()
        phase = .paused
    }

    func resume() {
        guard phase == .paused || phase == .interrupted else { return }
        do {
            try session.activate()
        } catch {
            errorMessage = "We couldn't continue recording. Please try again."
            return
        }
        if recorder?.record() == true {
            startMeterTimer()
            phase = .recording
        } else {
            // The previous segment couldn't resume (e.g. after an interruption
            // tore it down); start a fresh one so nothing is lost.
            finaliseCurrentSegment()
            if beginNewSegment() {
                startMeterTimer()
                phase = .recording
            }
        }
    }

    // MARK: - Finish / discard

    /// Finishes recording and returns the draft, or nil if it was too short.
    @discardableResult
    func finish() -> RecordingDraft? {
        finaliseCurrentSegment()
        stopMeterTimer()
        session.deactivate()

        guard var finished = draft else {
            phase = .idle
            return nil
        }
        finished.duration = priorSegmentsDuration
        draft = finished
        store.save(finished)

        if finished.duration < RecordingLimits.minimumDuration {
            store.delete(finished)
            draft = nil
            resetLiveState()
            phase = .idle
            errorMessage = "That recording was too short. Please hold on a little longer next time."
            return nil
        }

        elapsed = finished.duration
        phase = .finished
        return finished
    }

    /// Throws the whole draft away (Start over, or a confirmed discard).
    func discard() {
        recorder?.stop()
        recorder = nil
        stopMeterTimer()
        session.deactivate()
        if let draft { store.delete(draft) }
        draft = nil
        resetLiveState()
        phase = .idle
    }

    private func resetLiveState() {
        elapsed = 0
        level = 0
        priorSegmentsDuration = 0
        lastPersistedElapsed = 0
        isApproachingLimit = false
    }

    /// Releases audio resources when the recording screen goes away while still
    /// active (a safety net for unexpected dismissal). The in-progress draft is
    /// left on disk so it stays recoverable; normal finish/discard paths have
    /// already cleaned up, so this is a no-op for them.
    func teardown() {
        switch phase {
        case .recording, .paused, .interrupted:
            stopMeterTimer()
            persistProgress()
            recorder?.stop()
            recorder = nil
            session.deactivate()
        default:
            break
        }
    }

    // MARK: - Segments

    private func beginNewSegment() -> Bool {
        guard let draft else { return false }
        let url = store.newSegmentURL(for: draft.id)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true
            guard newRecorder.record() else {
                fail("We couldn't start recording. Please try again.")
                return false
            }
            recorder = newRecorder
            var updated = draft
            updated.segmentFileNames.append(url.lastPathComponent)
            self.draft = updated
            store.save(updated)
            return true
        } catch {
            fail("We couldn't start recording. Please try again.")
            return false
        }
    }

    private func finaliseCurrentSegment() {
        guard let recorder else { return }
        priorSegmentsDuration += recorder.currentTime
        recorder.stop()
        self.recorder = nil
    }

    /// Total duration including the segment currently being recorded.
    private var totalDuration: TimeInterval {
        priorSegmentsDuration + (recorder?.currentTime ?? 0)
    }

    // MARK: - Metering & limit enforcement

    private func startMeterTimer() {
        stopMeterTimer()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func tick() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        level = Self.normalisedLevel(fromDecibels: recorder.averagePower(forChannel: 0))
        elapsed = totalDuration

        if elapsed >= RecordingLimits.warningThreshold {
            isApproachingLimit = true
        }
        if elapsed >= RecordingLimits.maximumDuration {
            // Auto-stop at the limit, preserving everything captured.
            finish()
            return
        }
        persistProgressThrottled()
    }

    private func persistProgressThrottled() {
        if elapsed - lastPersistedElapsed >= 2 {
            lastPersistedElapsed = elapsed
            persistProgress()
        }
    }

    private func persistProgress() {
        guard var draft else { return }
        draft.duration = totalDuration
        self.draft = draft
        store.save(draft)
    }

    /// Maps decibels (roughly -160...0 dBFS) to a 0...1 meter value.
    static func normalisedLevel(fromDecibels db: Float) -> Float {
        let floor: Float = -60
        if db < floor { return 0 }
        if db >= 0 { return 1 }
        return (db - floor) / (0 - floor)
    }

    // MARK: - Permission

    private func ensurePermission() async -> Bool {
        switch session.permissionStatus {
        case .granted: return true
        case .denied: return false
        case .undetermined: return await session.requestPermission()
        @unknown default: return await session.requestPermission()
        }
    }

    // MARK: - Interruptions (US-015 AC4)

    private func handleInterruptionBegan() {
        guard phase == .recording else { return }
        recorder?.pause()
        stopMeterTimer()
        persistProgress()
        phase = .interrupted
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        // Stay paused and let the user choose Resume or Finish, per the
        // acceptance criteria, rather than resuming silently. `shouldResume`
        // is intentionally not acted on for this reason.
        guard phase == .interrupted else { return }
    }

    // MARK: - Helpers

    private func fail(_ message: String) {
        errorMessage = message
        phase = .failed(message)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder,
                                                      error: Error?) {
        Task { @MainActor in
            self.stopMeterTimer()
            self.persistProgress()
            self.errorMessage = "Something interrupted the recording. What you have so far has been kept."
            self.phase = .paused
        }
    }
}
