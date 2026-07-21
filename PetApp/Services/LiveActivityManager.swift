//
//  LiveActivityManager.swift
//  PetApp  <-- app target
//
//  Starts/updates/ends the FeedActivityAttributes Live Activity defined in
//  FeedLiveActivity.swift (widget extension target). This is the piece that
//  actually puts the "Feed me!" card on the Lock Screen — without calling
//  start(), the Feed button has nothing to attach to.
//

import ActivityKit
import WidgetKit

@MainActor
enum LiveActivityManager {

    /// Call this when the pet becomes hungry (e.g. from your feeding-schedule logic).
    static func start(companionAssetName: String, hungerLevel: Int) {
        // Only one Feed activity should run at a time.
        guard Activity<FeedActivityAttributes>.activities.isEmpty else { return }

        let attributes = FeedActivityAttributes(companionAssetName: companionAssetName)
        let state = FeedActivityAttributes.ContentState(isHungry: true, hungerLevel: hungerLevel)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }

        // Keep the shared snapshot (read by all widgets) in sync too.
        var data = PetWidgetStore.load()
        data.isHungry = true
        data.hungerLevel = hungerLevel
        PetWidgetStore.save(data)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Shared by: the in-app Feed button, and as a fallback if the Live
    /// Activity button's AppIntent didn't get a chance to run (e.g. the
    /// activity already ended). Keeps every surface in agreement.
    static func feed() async {
        PetWidgetStore.markFed()
        WidgetCenter.shared.reloadAllTimelines()

        for activity in Activity<FeedActivityAttributes>.activities {
            let state = FeedActivityAttributes.ContentState(isHungry: false, hungerLevel: 5)
            await activity.update(ActivityContent(state: state, staleDate: nil))
            // End it a few seconds after showing "All fed, thank you!"
            try? await Task.sleep(for: .seconds(3))
            await activity.end(nil, dismissalPolicy: .default)
        }
    }
}
