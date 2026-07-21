//
//  CompanionprofilePersistence.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//

import Foundation
 
extension CompanionProfile {
    /// Converts the onboarding draft into a persisted `Companion` once the
    /// user confirms Step 3 of onboarding. Call this, then `CompanionStore
    /// .clearDraft()`, then insert the result into the ModelContext.
    ///
    ///     let companion = profile.makeCompanion(owner: currentUser)
    ///     modelContext.insert(companion)
    ///     companionStore.clearDraft()
    ///
    func makeCompanion(owner: User?) -> Companion {
        Companion(
            kind: kind,
            colorVariant: colorHex,
            name: name,
            careFrequencyLabel: Self.label(forDays: careFrequencyDays),
            becomesUnwellIfNotFed: sickIfNotFed,
            vibrateWhenFed: vibrateWhenFed,
            owner: owner
        )
    }
 
    /// Maps the onboarding slider's numeric value onto the plain-language
    /// interval the spec calls for — the raw number is never shown in UI.
    /// TODO: confirm exact wording/breakpoints with design; placeholder logic below.
    private static func label(forDays days: Int) -> String {
        switch days {
        case ..<1:  return "Every day"
        case 1:     return "Once a day"
        case 2:     return "Every two days"
        case 3...6: return "\(days) times a week"
        case 7:     return "Once a week"
        default:    return "Every \(days) days"
        }
    }
}
