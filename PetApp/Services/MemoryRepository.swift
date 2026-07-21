//
//  MemoryRepository.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//

import Foundation
 
/// Single write path for memories — used by the save-recording flow and
/// later by export/widgets. Build against `InMemoryMemoryRepository` until
/// the real SwiftData-backed implementation lands; the interface won't change.
protocol MemoryRepository {
    func fetchAll() async throws -> [MemorySummary]
    func fetch(id: String) async throws -> MemorySummary?
    func save(_ memory: MemorySummary) async throws
    func delete(id: String) async throws
    func setFavourite(id: String, isFavourite: Bool) async throws
}
 
/// A plain-data snapshot of a Memory, decoupled from the SwiftData @Model
/// type so consumers (widgets, export) don't need to link against SwiftData.
struct MemorySummary: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var transcript: String
    var date: Date
    var audioFileName: String
    var photoFileName: String?
    var isFavourite: Bool
}
 
/// Stub with fake seeded data. Swap the concrete type at the call site once
/// the real repository is ready — nothing else needs to change.
final class InMemoryMemoryRepository: MemoryRepository {
    private var memories: [MemorySummary]
 
    init(seeded: Bool = true) {
        self.memories = seeded ? Self.sampleData : []
    }
 
    func fetchAll() async throws -> [MemorySummary] {
        memories.sorted { $0.date > $1.date }
    }
 
    func fetch(id: String) async throws -> MemorySummary? {
        memories.first { $0.id == id }
    }
 
    func save(_ memory: MemorySummary) async throws {
        if let index = memories.firstIndex(where: { $0.id == memory.id }) {
            memories[index] = memory
        } else {
            memories.append(memory)
        }
    }
 
    func delete(id: String) async throws {
        memories.removeAll { $0.id == id }
    }
 
    func setFavourite(id: String, isFavourite: Bool) async throws {
        guard let index = memories.firstIndex(where: { $0.id == id }) else { return }
        memories[index].isFavourite = isFavourite
    }
 
    private static let sampleData: [MemorySummary] = [
        MemorySummary(
            id: "sample-1",
            title: "A walk in the garden",
            transcript: "Today I spent some time outside deadheading the roses.",
            date: .now.addingTimeInterval(-86_400 * 2),
            audioFileName: "sample-1.m4a",
            photoFileName: "sample-1.jpg",
            isFavourite: true
        ),
        MemorySummary(
            id: "sample-2",
            title: "Sunday phone call with the grandkids",
            transcript: "Had a lovely chat about their school trip.",
            date: .now.addingTimeInterval(-86_400 * 5),
            audioFileName: "sample-2.m4a",
            photoFileName: nil,
            isFavourite: false
        )
    ]
}
 
