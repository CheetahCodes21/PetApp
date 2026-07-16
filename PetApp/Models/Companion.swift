//
//  Companion.swift
//  PetApp
//
//  The virtual companion the user chooses during onboarding.
//

import SwiftUI

enum Companion: String, CaseIterable, Identifiable, Codable {
    case chicken
    case dino
    case penguin
    case pig

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chicken: return "Chicken"
        case .dino: return "Dino"
        case .penguin: return "Penguin"
        case .pig: return "Pig"
        }
    }

    /// Emoji stand-in for the companion art until real assets are added.
    var emoji: String {
        switch self {
        case .chicken: return "🐤"
        case .dino: return "🦕"
        case .penguin: return "🐧"
        case .pig: return "🐷"
        }
    }
}
