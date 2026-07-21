//
//  CompanionColourOption.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//

//
//  CompanionColorOption.swift
//  PetApp
//
//  Named colour variants for companion recolouring. Each case corresponds
//  to a set of pre-rendered Lottie files (one per hunger state / action),
//  not a runtime tint — so this needs to be a real identifier, not just a
//  hex string, since it's used to build asset filenames as well as UI
//  colour swatches.
//
 
import SwiftUI
 
enum CompanionColorOption: String, Codable, CaseIterable, Identifiable {
    case purple, pink, amber, green, blue, red
 
    var id: String { rawValue }
 
    /// For UI only (colour picker swatches) — not used for asset lookup.
    var hex: String {
        switch self {
        case .purple: return "#6B4E9E"
        case .pink:   return "#E4739A"
        case .amber:  return "#F2A65A"
        case .green:  return "#5EAE7E"
        case .blue:   return "#5A9BD4"
        case .red:    return "#C0504D"
        }
    }
 
    var color: Color { Color(hex: hex) }
 
    /// Used to build Lottie file names, e.g. "pet-purple-good-idle".
    /// Must match whatever naming convention the animator exports —
    /// confirm before wiring this into real asset loading.
    var assetSlug: String { rawValue }
 
    static let `default`: CompanionColorOption = .purple
}
 
