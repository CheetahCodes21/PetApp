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

    /// Clears the shared widget snapshot (e.g. on sign-out) and refreshes the
    /// widgets so they fall back to the placeholder instead of the last user's pet.
    static func clear() {
        PetWidgetStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func update(companion: Companion?, name: String, memories: [Memory]) {
        // No companion (signed out / brand-new account): show the gentle empty
        // prompt rather than stale or sample data.
        guard let companion else {
            PetWidgetStore.save(.empty)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let live = memories.filter { !$0.isDeleted }
        let thisMonth = live.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count

        // Hunger derived from the care window (1...3 hearts → widget's 0...5).
        let hearts = companion.hungerHearts
        let hungerLevel = [1: 1, 2: 3, 3: 5][hearts] ?? 5

        // Streak = consecutive days (ending today) with at least one memory.
        let days = Set(live.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        // Pet artwork for the widget. Animated companions (the Rive cat, Lottie
        // plants) have no static image, so leave the asset empty — the widget
        // shows the mood emoji for those instead of a wrong stand-in picture.
        // Static animals (dog, cow, rabbit, goldfish) show their real artwork.
        let species = PetSpecies(rawValue: companion.petSpeciesRaw) ?? .default
        let hasStaticImage = companion.kind == .pet
            && !species.isAnimated
            && UIImage(named: species.assetName) != nil
        let asset = hasStaticImage ? species.assetName : ""

        let data = PetWidgetData(
            companionAssetName: asset,
            userFirstName: name.trimmingCharacters(in: .whitespaces).isEmpty ? "friend" : name,
            todaysQuestion: DailyPrompts.todayAnchor.anchor,
            isHungry: hearts < 3,
            hungerLevel: hungerLevel,
            dayStreak: streak,
            memoriesSavedTotal: live.count,
            memoriesThisMonth: thisMonth,
            memoriesGoalThisMonth: 20,
            companionName: companion.name,
            moodHearts: hearts,
            companionKind: companion.kind == .plant ? "plant" : "pet",
            hasCompanion: true
        )

        if asset.isEmpty {
            removeCompanionImage()
        } else {
            writeCompanionImage(assetName: asset)
        }
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

    /// Removes any previously-written companion image so an animated companion
    /// (cat/plant) doesn't keep showing a stale static picture in the widget.
    private static func removeCompanionImage() {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id) else { return }
        try? FileManager.default.removeItem(at: container.appendingPathComponent(companionImageName))
    }
}
