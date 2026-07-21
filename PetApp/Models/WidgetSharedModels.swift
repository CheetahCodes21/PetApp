//
//  WidgetSharedModels.swift
//  PetAppWidgets
//
//  Shared snapshot of pet/companion state written by the main app and read
//  by every widget + the Live Activity. Lives in an App Group so both the
//  app target and the widget extension target can see it.
//
//  SETUP REQUIRED (Xcode, not code):
//  1. Enable "App Groups" capability on BOTH the PetApp app target and the
//     new Widget Extension target.
//  2. Create/select the same group id on both, e.g. "group.com.yourteam.petapp",
//     and update AppGroup.id below to match.
//

import Foundation

enum AppGroup {
    static let id = "group.com.AppleFoundationProgram.PetApp"
}

/// Snapshot of everything the widgets/Live Activity need to render.
struct PetWidgetData: Codable {
    var companionAssetName: String
    var userFirstName: String
    var todaysQuestion: String
    var isHungry: Bool
    var hungerLevel: Int          // 0...5 filled hearts
    var dayStreak: Int
    var memoriesSavedTotal: Int
    var memoriesThisMonth: Int
    var memoriesGoalThisMonth: Int

    static let placeholder = PetWidgetData(
        companionAssetName: "dog1",
        userFirstName: "Margaret",
        todaysQuestion: "What did you do today?",
        isHungry: true,
        hungerLevel: 5,
        dayStreak: 12,
        memoriesSavedTotal: 47,
        memoriesThisMonth: 13,
        memoriesGoalThisMonth: 20
    )
}

/// Read/write access to the shared snapshot.
enum PetWidgetStore {
    private static let key = "petWidgetData"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }

    static func load() -> PetWidgetData {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(PetWidgetData.self, from: data)
        else { return .placeholder }
        return decoded
    }

    static func save(_ value: PetWidgetData) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    /// Call from the main app after feeding, so widgets/Live Activity refresh.
    static func markFed() {
        var value = load()
        value.isHungry = false
        value.hungerLevel = 5
        save(value)
    }
}
