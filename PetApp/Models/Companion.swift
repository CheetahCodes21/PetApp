import Foundation
import SwiftData
 
/// The user's pet or plant companion (onboarding Step 3, edit, and replace flows).
/// Kind and colour are the only customisation axes per spec — one pet design and
/// one plant design, each recolourable. Uses the shared `CompanionKind` enum
/// defined in CompanionProfile.swift rather than redeclaring it here.
@Model
final class Companion {
    var id: String
    var kind: CompanionKind
    var colorVariant: String   // CompanionColorOption.rawValue, e.g. "purple" — used to build Lottie file names
    var name: String

    // Selected species (asset-backed). petSpeciesRaw is a PetSpecies.rawValue,
    // plantSpeciesRaw a PlantSpecies.rawValue; the active one depends on `kind`.
    var petSpeciesRaw: String = PetSpecies.default.rawValue
    var plantSpeciesRaw: String = PlantSpecies.default.rawValue
 
    /// Plain-language interval, e.g. "Once a day", "Every two days" — never a raw number.
    var careFrequencyLabel: String
    /// Numeric care window in days — how long before the companion gets hungry
    /// (and, if `becomesUnwellIfNotFed`, turns sick). Drives hunger decay.
    var careFrequencyDays: Int = 7
    var becomesUnwellIfNotFed: Bool
    var vibrateWhenFed: Bool
 
    var currentHungerState: String   // "good", "hungry", "veryHungry"
    var isUnwell: Bool
    var streakCount: Int
    var lastFedAt: Date?
    var createdAt: Date
 
    var owner: User?
 
    @Relationship(deleteRule: .cascade, inverse: \Memory.companion)
    var memories: [Memory] = []
 
    init(
        id: String = UUID().uuidString,
        kind: CompanionKind,
        colorVariant: String,
        name: String,
        petSpeciesRaw: String = PetSpecies.default.rawValue,
        plantSpeciesRaw: String = PlantSpecies.default.rawValue,
        careFrequencyLabel: String,
        careFrequencyDays: Int = 7,
        becomesUnwellIfNotFed: Bool,
        vibrateWhenFed: Bool,
        currentHungerState: String = "good",
        isUnwell: Bool = false,
        streakCount: Int = 0,
        lastFedAt: Date? = nil,
        createdAt: Date = .now,
        owner: User? = nil
    ) {
        self.id = id
        self.kind = kind
        self.colorVariant = colorVariant
        self.name = name
        self.petSpeciesRaw = petSpeciesRaw
        self.plantSpeciesRaw = plantSpeciesRaw
        self.careFrequencyLabel = careFrequencyLabel
        self.careFrequencyDays = careFrequencyDays
        self.becomesUnwellIfNotFed = becomesUnwellIfNotFed
        self.vibrateWhenFed = vibrateWhenFed
        self.currentHungerState = currentHungerState
        self.isUnwell = isUnwell
        self.streakCount = streakCount
        self.lastFedAt = lastFedAt
        self.createdAt = createdAt
        self.owner = owner
    }
}

// MARK: - Hunger decay (derived from the care window)

extension Companion {
    /// 0 = just fed/watered, 1 = a full care window has elapsed.
    var feedingElapsedFraction: Double {
        let since = lastFedAt ?? createdAt
        let window = Double(max(1, careFrequencyDays)) * 86_400
        return max(0, Date().timeIntervalSince(since) / window)
    }

    /// Food-bar hearts (1...3): 3 = happy, 2 = hungry, 1 = very hungry.
    var hungerHearts: Int {
        switch feedingElapsedFraction {
        case ..<(1.0 / 3): return 3
        case ..<(2.0 / 3): return 2
        default:           return 1
        }
    }

    /// True once the care window has fully elapsed and the companion is set to
    /// become unwell when not cared for in time.
    var isSick: Bool {
        becomesUnwellIfNotFed && feedingElapsedFraction >= 1.0
    }

    /// The care action verb for this companion.
    var careVerb: String { kind == .plant ? "Water" : "Feed" }
}
