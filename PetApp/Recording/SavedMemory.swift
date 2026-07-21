//
//  SavedMemory.swift
//  PetApp
//
//  STUB (Dev 3, KAN-20): a minimal saved-memory model + store so the save flow
//  works end to end before Dev 4's real `Memory` / `MemoryRepository` land. When
//  they do, the save flow writes through Dev 4's repository instead, and this
//  file is deleted. Kept intentionally small — only the fields the save flow
//  produces (see PetApp/Recording/README.md hand-off table).
//

import Foundation

/// State of the transcript attached to a memory (US-016 AC3–5).
enum TranscriptState: String, Codable, Hashable {
    case none      // audio-only, no transcript requested
    case pending   // transcription still running
    case ready     // transcript attached
    case failed    // transcription failed; a retry can be offered later
}

/// A saved memory. Placeholder for Dev 4's `Memory` type.
struct SavedMemory: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var createdAt: Date
    /// Assembled audio file name, relative to the memories directory.
    var audioFileName: String
    var duration: TimeInterval
    var questionText: String?
    var transcript: String
    var transcriptState: TranscriptState
    /// Attached photo file name, relative to the memories directory (KAN-21).
    var photoFileName: String?

    init(id: String = UUID().uuidString,
         title: String,
         createdAt: Date,
         audioFileName: String,
         duration: TimeInterval,
         questionText: String? = nil,
         transcript: String = "",
         transcriptState: TranscriptState = .none,
         photoFileName: String? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.audioFileName = audioFileName
        self.duration = duration
        self.questionText = questionText
        self.transcript = transcript
        self.transcriptState = transcriptState
        self.photoFileName = photoFileName
    }
}

/// STUB store persisting memories as JSON plus their assembled audio, so the
/// flow is testable. Replaced by Dev 4's `MemoryRepository`.
@MainActor
final class MemoryStore {
    static let shared = MemoryStore()

    private let fileManager = FileManager.default
    let directory: URL

    init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("Memories", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        // Encrypt saved memories at rest (KAN-38).
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path)
    }

    func audioURL(named name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// A destination URL for a memory's assembled audio.
    func newAudioURL(for id: String) -> URL {
        directory.appendingPathComponent("\(id).m4a")
    }

    func photoURL(named name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    func newPhotoURL(for id: String) -> URL {
        directory.appendingPathComponent("\(id).jpg")
    }

    func save(_ memory: SavedMemory) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        try? data.write(to: directory.appendingPathComponent("\(memory.id).json"),
                        options: .atomic)
    }

    /// Attaches a transcript (or failure state) to an already-saved memory
    /// (US-016 AC4: transcription finishing after the memory was saved). No-op
    /// if the memory no longer exists. Dev 4's repository provides the real
    /// equivalent.
    func attachTranscript(memoryID: String, transcript: String, state: TranscriptState) {
        let url = directory.appendingPathComponent("\(memoryID).json")
        guard let data = try? Data(contentsOf: url),
              var memory = try? JSONDecoder().decode(SavedMemory.self, from: data) else { return }
        memory.transcript = transcript
        memory.transcriptState = state
        save(memory)
    }

    func all() -> [SavedMemory] {
        let files = (try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(SavedMemory.self, from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
