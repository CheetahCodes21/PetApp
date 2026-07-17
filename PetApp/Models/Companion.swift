//
//  Companion.swift
//  PetApp
//
//  The virtual companion the user chooses during onboarding.
//  Each case maps to an image asset in Assets.xcassets.
//

import SwiftUI

enum Companion: String, CaseIterable, Identifiable, Codable {
    case kangaroo
    case cat
    case cow
    case dog
    case fox
    case trex
    case penguin
    case goat
    case flamingo
    case squirrel
    case toucan
    case parrot

    var id: String { rawValue }

    /// Friendly name shown under each card and in copy.
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

    /// Exact asset-catalog name for this companion's artwork.
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
}
