//
//  FeedIntent.swift
//  PetAppWidgets
//
//  Lets the Live Activity's "Feed" button perform work without opening the
//  app. Runs in the widget extension process, so it can only touch shared
//  (App Group) storage — not the app's in-memory state directly.
//

import AppIntents
import ActivityKit
import WidgetKit

struct FeedPetIntent: AppIntent {
    static var title: LocalizedStringResource = "Feed Pet"
    static var description = IntentDescription("Feeds the companion and updates its mood.")

    // Runs in the background without bringing the app to the foreground.
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        PetWidgetStore.markFed()

        // Update the running Live Activity, if any, so it reflects the fed state.
        if let activity = Activity<FeedActivityAttributes>.activities.first {
            let state = FeedActivityAttributes.ContentState(isHungry: false, hungerLevel: 5)
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
