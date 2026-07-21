//
//  RecordingModels.swift
//  PetApp
//
//  Core types for the audio workstream (KAN-19 / KAN-35): recording limits,
//  the live recorder phase, the on-disk draft, and the RecordingCoordinator
//  contract other features drive recording through.
//

import Foundation

// MARK: - Limits

/// How long a memory recording may run, agreed with the team.
/// Minimum 10 seconds, maximum 20 minutes.
enum RecordingLimits {
    /// Shortest recording we will keep. Below this the recording is discarded.
    static let minimumDuration: TimeInterval = 10
    /// Longest a single memory may run before recording stops automatically.
    static let maximumDuration: TimeInterval = 20 * 60
    /// When to warn that the limit is approaching (two minutes before the end).
    static let warningThreshold: TimeInterval = maximumDuration - 120
}

// MARK: - Phase

/// The live state of the recorder, surfaced to the UI.
enum RecorderPhase: Equatable {
    case idle
    case preparing
    case recording
    case paused
    /// Paused by the system (for example an incoming phone call). The user is
    /// offered Resume or Finish rather than resuming silently.
    case interrupted
    case finished
    case failed(String)
}

// MARK: - Draft

/// An in-progress or recovered recording, persisted to disk so it survives
/// interruptions, backgrounding, and app termination. A draft is made of one
/// or more audio segments — a new segment begins whenever recording resumes in
/// a fresh app session — that are stitched together when the memory is saved.
struct RecordingDraft: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var createdAt: Date
    var updatedAt: Date
    /// Ordered audio segment file names, relative to the drafts directory.
    var segmentFileNames: [String]
    /// Best-known total duration in seconds, updated as recording proceeds.
    var duration: TimeInterval
    /// The journalling question this answers, if recording began from one.
    var questionText: String?
    /// True once the memory has been saved (or, for now, explicitly kept),
    /// which removes it from the crash-recovery list.
    var isFinalised: Bool

    init(id: String = UUID().uuidString,
         createdAt: Date = Date(),
         questionText: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.segmentFileNames = []
        self.duration = 0
        self.questionText = questionText
        self.isFinalised = false
    }
}

// MARK: - Coordinator contract

/// The single entry point other features use to capture audio, so the recorder
/// is never duplicated. Dev 2's "unwell companion" flow and Dev 5's widgets both
/// drive recording through this contract. The real implementation lands with the
/// save-memory flow (KAN-20); until then callers can use `MockRecordingCoordinator`.
@MainActor
protocol RecordingCoordinator {
    /// Presents the recording flow and returns the resulting draft, or nil if
    /// the user backed out without keeping anything.
    func recordMemory(forQuestion question: String?) async -> RecordingDraft?
}

/// Stand-in used until the real coordinator ships, returning a fixed sample
/// draft so dependent screens can be built and previewed.
@MainActor
final class MockRecordingCoordinator: RecordingCoordinator {
    func recordMemory(forQuestion question: String?) async -> RecordingDraft? {
        var draft = RecordingDraft(questionText: question)
        draft.duration = 12
        return draft
    }
}
