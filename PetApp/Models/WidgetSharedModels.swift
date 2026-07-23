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

    // Added fields (optional for back-compat with older saved snapshots).
    /// The companion's given name (e.g. "Bruno").
    var companionName: String?
    /// Happiness, 1...3 (3 = happy, 2 = neutral, 1 = sad).
    var moodHearts: Int?
    /// "pet" or "plant" — chooses the fallback glyph when there's no image.
    var companionKind: String?
    /// False once the user has signed out / has no companion, so widgets show a
    /// gentle "open the app" prompt instead of stale or sample stats.
    var hasCompanion: Bool?

    /// Face reflecting happiness: 3 hearts happy, 2 neutral, 1 sad.
    var moodEmoji: String {
        switch moodHearts ?? 3 {
        case 3:  return "😊"
        case 2:  return "😐"
        default: return "😢"
        }
    }

    var isSignedOut: Bool { hasCompanion == false }

    /// Sample data shown in the widget gallery / previews only.
    static let placeholder = PetWidgetData(
        companionAssetName: "dog1",
        userFirstName: "friend",
        todaysQuestion: "What made you smile today?",
        isHungry: false,
        hungerLevel: 5,
        dayStreak: 3,
        memoriesSavedTotal: 12,
        memoriesThisMonth: 5,
        memoriesGoalThisMonth: 20,
        companionName: "Buddy",
        moodHearts: 3,
        companionKind: "pet",
        hasCompanion: true
    )

    /// Shown when signed out or before the app has written any real data.
    static let empty = PetWidgetData(
        companionAssetName: "dog1",
        userFirstName: "friend",
        todaysQuestion: "Open MemoMe to meet your companion.",
        isHungry: false,
        hungerLevel: 0,
        dayStreak: 0,
        memoriesSavedTotal: 0,
        memoriesThisMonth: 0,
        memoriesGoalThisMonth: 20,
        companionName: nil,
        moodHearts: 3,
        companionKind: "pet",
        hasCompanion: false
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
        else { return .empty }   // no real data yet → gentle prompt, not fake stats
        return decoded
    }

    static func save(_ value: PetWidgetData) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    /// Clears the shared widget data (e.g. on sign-out) so the widget doesn't
    /// keep showing a signed-out user's pet and stats.
    static func clear() {
        defaults.removeObject(forKey: key)
    }

    /// Call from the main app after feeding, so widgets/Live Activity refresh.
    static func markFed() {
        var value = load()
        value.isHungry = false
        value.hungerLevel = 5
        save(value)
    }
}
