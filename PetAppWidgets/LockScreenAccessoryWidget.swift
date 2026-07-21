//
//  LockScreenAccessoryWidget.swift
//  PetAppWidgets
//
//  Lock Screen widget. NOTE: iOS renders .accessoryRectangular widgets in a
//  single system-controlled tint (monochrome/vibrant), not full color, and
//  they cannot host tappable buttons — only a whole-widget tap via widgetURL.
//  Icons, hearts, and text below will all render in one tint on-device even
//  though this preview shows fuller color and a mic glyph as a static icon.
//

import WidgetKit
import SwiftUI

struct LockScreenPetWidget: Widget {
    let kind = "LockScreenPetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            LockScreenPetView(entry: entry)
        }
        .configurationDisplayName("Pet")
        .description("Today's question, or a reminder to feed your pet.")
        .supportedFamilies([.accessoryRectangular])
    }
}

private struct LockScreenPetView: View {
    let entry: PetEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(entry.data.companionAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                if entry.data.isHungry {
                    Text("Feed me!")
                        .font(.caption2.weight(.bold))
                    Text("Pet is hungry")
                        .font(.headline)
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .opacity(i < entry.data.hungerLevel ? 1 : 0.3)
                        }
                    }
                } else {
                    Text("Hi, \(entry.data.userFirstName)!")
                        .font(.headline)
                    Text(entry.data.todaysQuestion)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "petapp://\(entry.data.isHungry ? "feed" : "question")"))
    }
}

#Preview(as: .accessoryRectangular) {
    LockScreenPetWidget()
} timeline: {
    PetEntry(date: .now, data: .placeholder)
    PetEntry(date: .now, data: {
        var d = PetWidgetData.placeholder
        d.isHungry = false
        return d
    }())
}
