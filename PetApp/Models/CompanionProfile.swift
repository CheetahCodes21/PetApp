//
//  CompanionProfile.swift
//  PetApp
//
//  The user's chosen MemoMe companion (a pet or a plant) and its care
//  preferences, configured during onboarding. This is the lightweight,
//  easily-discardable draft used *while onboarding is in progress* — it's
//  converted into the persisted `Companion` (SwiftData) once the user
//  confirms Step 3. See CompanionprofilePersistence.swift.
//
//  Per spec: one pet design and one plant design, each recolourable —
//  no species or plant-type picker.
//
 
import SwiftUI
import Combine
 
enum CompanionKind: String, Codable, CaseIterable, Identifiable {
    case pet, plant
    var id: String { rawValue }
    var title: String { self == .pet ? "Pet" : "Plant" }
    var systemImage: String { self == .pet ? "pawprint.fill" : "leaf.fill" }
}
 
struct CompanionProfile: Codable, Equatable {
    var kind: CompanionKind = .pet
    var colorOption: CompanionColorOption = .default
    var name: String = ""
    /// How many days the feeding window lasts (1–15). Converted to a
    /// plain-language label before being shown anywhere in UI.
    var careFrequencyDays: Int = 7
    var sickIfNotFed: Bool = false
    var vibrateWhenFed: Bool = true
 
    var color: Color { colorOption.color }
 
    /// Preview of the currently selected companion, recoloured to `color`.
    ///
    /// TODO(Rain): only the default flower idle animation exists in the
    /// bundle today ("FlowerIdleDisplay"). Once per-colour Lottie exports
    /// land (e.g. "pet-purple-good-idle", "plant-purple-good-idle"), swap
    /// the placeholder below for `LottieView(name: animationFileName)`.
    /// The pawprint/leaf symbols here are a visible stand-in, not final art.
    @ViewBuilder
    var preview: some View {
        switch kind {
        case .pet:
            RiveCatView(hearts: 3, isSick: false, color: color)
        case .plant:
            RivePlantView(isSick: false, color: color)
        }
    }
}
 
// MARK: - Onboarding draft store
 
@MainActor
final class CompanionStore: ObservableObject {
    private let defaults = UserDefaults.standard
    private let key = "companion.profile.draft"
 
    @Published var profile: CompanionProfile? {
        didSet { persist() }
    }
 
    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(CompanionProfile.self, from: data) {
            profile = decoded
        }
    }
 
    func save(_ profile: CompanionProfile) {
        self.profile = profile
    }
 
    /// Clears the draft once it's been converted into a persisted `Companion`
    /// at the end of onboarding — call this right after `makeCompanion(owner:)`.
    func clearDraft() {
        profile = nil
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
