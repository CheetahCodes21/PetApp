//
//  DraftStore.swift
//  PetApp
//
//  Persists recording drafts to disk and recovers them after interruptions or
//  termination (KAN-35, "Never lose a recording"). Each draft is a JSON
//  metadata sidecar plus its audio segments, all kept in the drafts directory.
//  Metadata is rewritten on every meaningful change so a draft is always
//  recoverable, even if the app is force quit mid-recording.
//

import Foundation

@MainActor
final class DraftStore {
    static let shared = DraftStore()

    private let fileManager = FileManager.default

    /// Root directory for all drafts, inside Application Support.
    let draftsDirectory: URL

    init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? FileManager.default.temporaryDirectory
        draftsDirectory = base.appendingPathComponent("Recordings", isDirectory: true)
        try? fileManager.createDirectory(at: draftsDirectory,
                                         withIntermediateDirectories: true)
        // Encrypt recordings at rest (KAN-38). Files created here inherit this
        // protection; "until first unlock" keeps a recording accessible if the
        // screen locks mid-session, while still encrypting on disk.
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: draftsDirectory.path)
    }

    // MARK: - Paths

    func metadataURL(for id: String) -> URL {
        draftsDirectory.appendingPathComponent("\(id).json")
    }

    func segmentURL(named name: String) -> URL {
        draftsDirectory.appendingPathComponent(name)
    }

    /// A fresh, unique segment file URL for the given draft.
    func newSegmentURL(for draftID: String) -> URL {
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        return draftsDirectory.appendingPathComponent("\(draftID)-\(stamp).m4a")
    }

    // MARK: - Persistence

    func save(_ draft: RecordingDraft) {
        var draft = draft
        draft.updatedAt = Date()
        do {
            let data = try JSONEncoder().encode(draft)
            try data.write(to: metadataURL(for: draft.id), options: .atomic)
        } catch {
            // Non-fatal: the audio is still on disk; only the sidecar failed to
            // update. The next successful save reconciles it.
        }
    }

    func load(id: String) -> RecordingDraft? {
        guard let data = try? Data(contentsOf: metadataURL(for: id)) else { return nil }
        return try? JSONDecoder().decode(RecordingDraft.self, from: data)
    }

    /// Marks a draft as kept/saved so it no longer appears in recovery.
    func markFinalised(_ draft: RecordingDraft) {
        var updated = draft
        updated.isFinalised = true
        save(updated)
    }

    /// Drafts that were never finalised and still have audio on disk — the
    /// candidates offered for crash recovery on next launch.
    func recoverableDrafts() -> [RecordingDraft] {
        let files = (try? fileManager.contentsOfDirectory(
            at: draftsDirectory,
            includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(RecordingDraft.self, from: $0) }
            .filter { !$0.isFinalised && !$0.segmentFileNames.isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func delete(_ draft: RecordingDraft) {
        for name in draft.segmentFileNames {
            try? fileManager.removeItem(at: segmentURL(named: name))
        }
        try? fileManager.removeItem(at: metadataURL(for: draft.id))
    }

    // MARK: - Storage headroom (US-015 AC5: warn before recording, not after)

    /// Available capacity in bytes on the volume holding our drafts.
    func availableBytes() -> Int64 {
        let values = try? draftsDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    /// Rough bytes needed for a full-length AAC voice recording, with headroom.
    var estimatedBytesForMaxRecording: Int64 {
        // ~16 KB/s AAC voice × maximum length, doubled for safety.
        Int64(16_000 * RecordingLimits.maximumDuration * 2)
    }

    func hasRoomToRecord() -> Bool {
        let available = availableBytes()
        // If free space can't be determined (returns 0), don't block recording —
        // fail open so a reporting quirk never stops the core feature.
        guard available > 0 else { return true }
        return available > estimatedBytesForMaxRecording
    }
}
