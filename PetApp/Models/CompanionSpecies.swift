//
//  CompanionSpecies.swift
//  PetApp
//
//  Selectable companion species, backed by the image assets in
//  Assets.xcassets (pets) and bundled Lottie animations (plants).
//
//  NOTE: This adds a per-species picker on top of the simplified kind +
//  colour model. Coordinate with the data-model owner before relying on it
//  long-term.
//

import SwiftUI

enum PetSpecies: String, CaseIterable, Identifiable, Codable {
    // Only species with real art in Assets.xcassets (plus the animated Rive
    // cat). Add a case here when its image is added to the catalog.
    case cat, dog, cow, rabbit, goldfish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cat:      return "Cat"
        case .dog:      return "Dog"
        case .cow:      return "Cow"
        case .rabbit:   return "Rabbit"
        case .goldfish: return "Goldfish"
        }
    }

    /// Exact asset-catalog name for this species' artwork. Unused for `.cat`,
    /// which is rendered with the animated Rive scene (see `isAnimated`).
    var assetName: String {
        switch self {
        case .cat:      return "Cat"
        case .dog:      return "Dog"
        case .cow:      return "cow1"
        case .rabbit:   return "Rabbit"
        case .goldfish: return "Goldfish"
        }
    }

    var image: Image { Image(assetName) }

    /// Whether this species is rendered with the animated Rive scene rather
    /// than a static image.
    var isAnimated: Bool { self == .cat }

    static let `default`: PetSpecies = .cat
}

enum PlantSpecies: String, CaseIterable, Identifiable, Codable {
    // sprout = animated Rive plant (plant.riv); flower = Lottie idle animation.
    case sprout, flower

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sprout: return "Sprout"
        case .flower: return "Flower"
        }
    }

    /// Animated plants render with Rive (RivePlantView); others use Lottie.
    var isAnimated: Bool { self == .sprout }

    /// Bundled Lottie animation for this plant (unused for animated species).
    var lottieName: String {
        switch self {
        case .sprout: return "FlowerDefaultIdle"
        case .flower: return "FlowerDefaultIdle"
        }
    }

    static let `default`: PlantSpecies = .sprout
}
