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
    case kangaroo, cat, cow, dog, fox

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kangaroo: return "Kangaroo"
        case .cat:      return "Cat"
        case .cow:      return "Cow"
        case .dog:      return "Dog"
        case .fox:      return "Fox"
        }
    }

    /// Exact asset-catalog name for this species' artwork.
    var assetName: String {
        switch self {
        case .kangaroo: return "Aussie Kangaroo"
        case .cat:      return "cat1"
        case .cow:      return "cow1"
        case .dog:      return "dog1"
        case .fox:      return "Fox"

        }
    }

    var image: Image { Image(assetName) }

    static let `default`: PetSpecies = .dog
}

enum PlantSpecies: String, CaseIterable, Identifiable, Codable {
    case flower

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flower: return "Flower"
        }
    }

    /// Bundled Lottie animation for this plant.
    var lottieName: String {
        switch self {
        case .flower: return "FlowerDefaultIdle"
        }
    }

    static let `default`: PlantSpecies = .flower
}
