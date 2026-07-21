//
//  CompanionProfile.swift
//  PetApp
//
//  The user's chosen MemoMe companion (a pet or a plant) and its care
//  preferences, configured during onboarding and persisted.
//

import SwiftUI
import Combine
import UIKit

enum CompanionKind: String, Codable, CaseIterable, Identifiable {
    case pet, plant
    var id: String { rawValue }
    var title: String { self == .pet ? "Pet" : "Plant" }
    var systemImage: String { self == .pet ? "pawprint.fill" : "leaf.fill" }
}

/// Plant companions (pets reuse the existing `Companion` image assets).
enum PlantType: String, Codable, CaseIterable, Identifiable {
    case flower, sprout, cactus, sunflower, tulip, fern

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flower:    return "Flower"
        case .sprout:    return "Sprout"
        case .cactus:    return "Cactus"
        case .sunflower: return "Sunflower"
        case .tulip:     return "Tulip"
        case .fern:      return "Fern"
        }
    }

    var emoji: String {
        switch self {
        case .flower:    return "🌸"
        case .sprout:    return "🌱"
        case .cactus:    return "🌵"
        case .sunflower: return "🌻"
        case .tulip:     return "🌷"
        case .fern:      return "🪴"
        }
    }

    /// Name of a bundled Lottie animation for this plant, if it has one.
    /// Plants without an animation fall back to their emoji.
    var lottieName: String? {
        switch self {
        case .flower: return "FlowerIdleDisplay"
        default:      return nil
        }
    }
}

/// Preset accent colors for companion customisation.
enum CompanionColor {
    static let palette: [String] = [
        "#6B4E9E", // purple
        "#E4739A", // pink
        "#F2A65A", // amber
        "#5EAE7E", // green
        "#5A9BD4", // blue
        "#C0504D", // red
    ]
    static let defaultHex = palette[0]
}

struct CompanionProfile: Codable, Equatable {
    var kind: CompanionKind = .pet
    var petSpecies: Companion = .dog
    var plantType: PlantType = .sprout
    var colorHex: String = CompanionColor.defaultHex
    var name: String = ""
    /// How many days the feeding window lasts (1–15).
    var careFrequencyDays: Int = 7
    /// Whether the companion shows a "sick" state if not fed in time.
    var sickIfNotFed: Bool = false
    /// Whether the phone vibrates when the companion is fed.
    var vibrateWhenFed: Bool = true

    var color: Color { Color(hex: colorHex) }

    /// Emoji / art preview for the currently selected companion.
    @ViewBuilder
    var preview: some View {
        switch kind {
        case .pet:
            petSpecies.image
                .resizable()
                .scaledToFit()
        case .plant:
            if let lottie = plantType.lottieName {
                LottieView(name: lottie)
            } else {
                Text(plantType.emoji)
                    .font(.system(size: 90))
            }
        }
    }
}

// MARK: - Persisted store

@MainActor
final class CompanionStore: ObservableObject {
    private let defaults = UserDefaults.standard
    private let key = "companion.profile"
    private let fedKey = "companion.lastFedAt"

    @Published var profile: CompanionProfile? {
        didSet { persist() }
    }

    /// When the companion was last fed. Drives the food bar decay.
    @Published var lastFedAt: Date {
        didSet { defaults.set(lastFedAt.timeIntervalSince1970, forKey: fedKey) }
    }

    init() {
        let storedFed = defaults.double(forKey: fedKey)
        lastFedAt = storedFed > 0 ? Date(timeIntervalSince1970: storedFed) : Date()

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(CompanionProfile.self, from: data) {
            profile = decoded
        }
    }

    func save(_ profile: CompanionProfile) {
        self.profile = profile
    }

    // MARK: - Feeding

    /// Feeding level 0...1 that decays over the care-frequency window.
    /// One feed always resets it to full — no partial catch-up.
    var feedingFraction: Double {
        guard let days = profile?.careFrequencyDays, days > 0 else { return 1 }
        let window = Double(days) * 86_400
        let elapsed = Date().timeIntervalSince(lastFedAt)
        return max(0, min(1, 1 - elapsed / window))
    }

    /// Number of filled hearts (out of 3) for the food bar.
    var filledHearts: Int {
        Int((feedingFraction * 3).rounded())
    }

    func feed() {
        lastFedAt = Date()
        if profile?.vibrateWhenFed == true {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func persist() {
        guard let profile,
              let data = try? JSONEncoder().encode(profile) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
