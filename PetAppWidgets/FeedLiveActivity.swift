//
//  FeedLiveActivity.swift
//  PetAppWidgets
//
//  This is the "Feed" card shown near the Lock Screen clock in your mockup
//  (leftmost screenshot). That look — full color, an interactive button —
//  is what Live Activities are for; a plain accessory widget can't do this.
//
//  SETUP REQUIRED (Xcode, not code):
//  1. In the app target's Info.plist, add:
//     NSSupportsLiveActivities = YES
//  2. Start the activity from the main app when the pet becomes hungry, e.g.:
//       let attrs = FeedActivityAttributes(companionAssetName: "chick")
//       let state = FeedActivityAttributes.ContentState(isHungry: true, hungerLevel: 2)
//       try Activity.request(attributes: attrs,
//                             content: .init(state: state, staleDate: nil))
//  3. End the activity once fed for a while, or let it go stale.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FeedLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            FeedActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(hex: "#F5F2FB"))
                .activitySystemActionForegroundColor(Color(hex: "#221B2B"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(context.attributes.companionAssetName)
                        .resizable().scaledToFit().frame(width: 32, height: 32)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: FeedPetIntent()) {
                        Text("Feed")
                    }
                    .tint(Color(hex: "#47293F"))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("It's time to feed me!")
                        .font(.footnote.weight(.semibold))
                }
            } compactLeading: {
                Image(context.attributes.companionAssetName)
                    .resizable().scaledToFit()
            } compactTrailing: {
                Image(systemName: "fork.knife")
            } minimal: {
                Image(context.attributes.companionAssetName)
                    .resizable().scaledToFit()
            }
        }
    }
}

private struct FeedActivityLockScreenView: View {
    let context: ActivityViewContext<FeedActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(context.attributes.companionAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)

            Text(context.state.isHungry ? "It's time to feed me!" : "All fed, thank you!")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hex: "#221B2B"))

            Spacer(minLength: 0)

            if context.state.isHungry {
                Button(intent: FeedPetIntent()) {
                    Text("Feed")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#47293F"))
            }
        }
        .padding(16)
    }
}

// MARK: - Local hex helper (remove if Theme.swift's Color(hex:) is shared into this target)

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

#Preview("Live Activity", as: .content, using: FeedActivityAttributes(companionAssetName: "chick")) {
    FeedLiveActivityWidget()
} contentStates: {
    FeedActivityAttributes.ContentState(isHungry: true, hungerLevel: 2)
    FeedActivityAttributes.ContentState(isHungry: false, hungerLevel: 5)
}
