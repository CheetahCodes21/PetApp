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
    var colorVariant: String   // hex string, matches CompanionColor.palette values
    var name: String
 
    /// Plain-language interval, e.g. "Once a day", "Every two days" — never a raw number.
    var careFrequencyLabel: String
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
        careFrequencyLabel: String,
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
        self.careFrequencyLabel = careFrequencyLabel
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
