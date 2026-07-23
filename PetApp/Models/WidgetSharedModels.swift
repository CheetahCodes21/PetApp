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
//  2. Create/select the same group id on both — this must match the id in
//     PetApp.entitlements and PetAppWidgetsExtension.entitlements exactly,
//     and match AppGroup.id below. A mismatch doesn't crash or error; it
//     just silently falls back to each process's own separate UserDefaults,
//     so the widget always reads empty/stale data even though the app has
//     real data — that's what happened here (this was "group.com.yourteam.petapp",
//     a placeholder that didn't match the registered "group.com.AppleFoundationProgram.PetApp").
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
    /// True when the growth object is a plant rather than a pet. Plants have
    /// no static widget image of their own real artwork (only a Lottie
    /// animation in-app), so the widget shows recoloured template art instead.
    var isPlant: Bool = false
 
    // Added fields (optional for back-compat with older saved snapshots).
    /// The companion's given name (e.g. "Bruno").
    var companionName: String?
    /// Happiness, 1...3 (3 = happy, 2 = neutral, 1 = sad).
    var moodHearts: Int?
    /// "pet" or "plant" — chooses the fallback glyph when there's no image.
    var companionKind: String?
    /// Hex colour of the user's chosen companion recolour (e.g. "#6B4E9E"),
    /// used to tint the widget's static cat/plant template art so it matches
    /// what's shown in the app. Nil falls back to the default purple.
    var companionColorHex: String?
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
        companionAssetName: "chick",
        userFirstName: "Margaret",
        todaysQuestion: "What did you do today?",
        isHungry: true,
        hungerLevel: 5,
        dayStreak: 12,
        memoriesSavedTotal: 47,
        memoriesThisMonth: 13,
        memoriesGoalThisMonth: 20,
        isPlant: false
    )
 
    /// Shown when there's no real data yet — signed out, brand-new account,
    /// or nothing has ever been synced. Widgets use this to show a gentle
    /// "open the app" prompt instead of stale or fabricated stats.
    static let empty = PetWidgetData(
        companionAssetName: "",
        userFirstName: "friend",
        todaysQuestion: "Open MemoMe to get started",
        isHungry: false,
        hungerLevel: 0,
        dayStreak: 0,
        memoriesSavedTotal: 0,
        memoriesThisMonth: 0,
        memoriesGoalThisMonth: 20,
        isPlant: false,
        companionName: nil,
        moodHearts: nil,
        companionKind: nil,
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
