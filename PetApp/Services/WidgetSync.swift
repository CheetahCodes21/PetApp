//
//  WidgetSync.swift
//  PetApp
//
//  Writes the current companion / streak / memory state into the shared
//  App Group snapshot the widgets + Live Activity read, then asks WidgetKit
//  to reload. Call it whenever that state changes (launch, feed, new memory).
//

import Foundation
import WidgetKit
import UIKit

@MainActor
enum WidgetSync {
    /// Filename of the companion image shared via the App Group container.
    static let companionImageName = "companion.png"

    static func update(companion: Companion?, name: String, memories: [Memory]) {
        let calendar = Calendar.current
        let now = Date()
        let live = memories.filter { !$0.isDeleted }
        let thisMonth = live.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count

        let hungerLevel: Int
        switch companion?.currentHungerState {
        case "veryHungry": hungerLevel = 1
        case "hungry":     hungerLevel = 3
        default:           hungerLevel = 5
        }

        // Pet artwork asset (plants fall back to the default pet image in the
        // widget, since plant companions are Lottie-only — no static image).
        let asset = (PetSpecies(rawValue: companion?.petSpeciesRaw ?? "") ?? .default).assetName

        let data = PetWidgetData(
            companionAssetName: asset,
            userFirstName: name.trimmingCharacters(in: .whitespaces).isEmpty ? "friend" : name,
            todaysQuestion: DailyPrompts.todayAnchor.anchor,
            isHungry: (companion?.currentHungerState ?? "good") != "good",
            hungerLevel: hungerLevel,
            dayStreak: companion?.streakCount ?? 0,
            memoriesSavedTotal: live.count,
            memoriesThisMonth: thisMonth,
            memoriesGoalThisMonth: 20
        )

        writeCompanionImage(assetName: asset)
        PetWidgetStore.save(data)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Copies the companion's artwork into the App Group container so the
    /// widget (which can't read the app's asset catalog) can display it.
    private static func writeCompanionImage(assetName: String) {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id) else { return }
        let url = container.appendingPathComponent(companionImageName)
        if let image = UIImage(named: assetName), let data = image.pngData() {
            try? data.write(to: url)
        }
    }
}
