//
//  Memory.swift
//  PetApp
//
//  A saved memory and a store for them. The recording/transcription flow is
//  future work; for now this backs the home streak/count and the Archive tab.
//

import SwiftUI
import Combine

struct Memory: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var transcript: String
    var date: Date
    var isFavorite: Bool = false
}

@MainActor
final class MemoryStore: ObservableObject {
    private let defaults = UserDefaults.standard
    private let key = "memories"

    @Published private(set) var memories: [Memory] = [] {
        didSet { persist() }
    }

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Memory].self, from: data) {
            memories = decoded
        }
    }

    var count: Int { memories.count }

    /// Consecutive days (ending today) that have at least one memory.
    var streak: Int {
        guard !memories.isEmpty else { return 0 }
        let calendar = Calendar.current
        let days = Set(memories.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    func add(_ memory: Memory) {
        memories.insert(memory, at: 0)
    }

    func delete(_ memory: Memory) {
        memories.removeAll { $0.id == memory.id }
    }

    func toggleFavorite(_ memory: Memory) {
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        memories[index].isFavorite.toggle()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(memories) {
            defaults.set(data, forKey: key)
        }
    }
}
