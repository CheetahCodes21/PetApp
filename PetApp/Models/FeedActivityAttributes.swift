//
//  FeedActivityAttributes.swift
//  Shared between the PetApp app target AND the PetAppWidgetsExtension
//  target — add this file to BOTH targets in the File Inspector.
//
//  The app needs this type to call Activity<FeedActivityAttributes>.request(),
//  and the widget extension needs it to define the Live Activity's UI and
//  the Feed button's AppIntent.
//

import ActivityKit

struct FeedActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isHungry: Bool
        var hungerLevel: Int
    }
    var companionAssetName: String
    /// True when the growth object is a plant rather than a pet — swaps
    /// "Feed me!" / "Feed" copy for "I need care!" / "Care" throughout.
    var isPlant: Bool = false
}
