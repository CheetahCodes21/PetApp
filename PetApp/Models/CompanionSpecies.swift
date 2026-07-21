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
    case kangaroo, cat, cow, dog, fox, trex, penguin, goat, flamingo, squirrel, toucan, parrot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kangaroo: return "Kangaroo"
        case .cat:      return "Cat"
        case .cow:      return "Cow"
        case .dog:      return "Dog"
        case .fox:      return "Fox"
        case .trex:     return "T-Rex"
        case .penguin:  return "Penguin"
        case .goat:     return "Goat"
        case .flamingo: return "Flamingo"
        case .squirrel: return "Squirrel"
        case .toucan:   return "Toucan"
        case .parrot:   return "Parrot"
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
        case .trex:     return "Fun T-rex"
        case .penguin:  return "Panguine"
        case .goat:     return "Ram:Goat1"
        case .flamingo: return "Siberrian Fleminfo"
        case .squirrel: return "Squirel gilleri"
        case .toucan:   return "toco toucan"
        case .parrot:   return "Toto Parrot"
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
