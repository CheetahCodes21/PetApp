//
//  HomeScreenWidgets.swift
//  PetAppWidgets
//
//  Home Screen widgets, styled to match the app's theme palette. The widget
//  extension doesn't share Theme.swift, so the theme colours are mirrored
//  locally below (kept in sync by hand).
//

import WidgetKit
import SwiftUI
import UIKit

/// Loads the companion image the app wrote into the shared App Group
/// container (the widget can't read the app's asset catalog directly).
private func companionImage() -> Image {
    if let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id),
       let ui = UIImage(contentsOfFile: container.appendingPathComponent("companion.png").path) {
        return Image(uiImage: ui)
    }
    return Image(systemName: "pawprint.fill")
}

// MARK: - Theme (mirrors the app's "App theme colours")

private extension Color {
    static let wThistle     = Color(hex: "#C8B8DB")
    static let wSnow        = Color(hex: "#F9F4F5")
    static let wBlackberry  = Color(hex: "#502F4C")
    static let wNinja       = Color(hex: "#735084")
    static let wHeart       = Color(hex: "#E0555F")
    static let wAmber       = Color(hex: "#E8912E")
}

private var lavenderBackground: some View {
    LinearGradient(colors: [Color.wThistle.opacity(0.9), Color.wSnow],
                   startPoint: .topLeading, endPoint: .bottomTrailing)
}

private var plumBackground: some View {
    LinearGradient(colors: [Color.wBlackberry, Color(hex: "#2C1838")],
                   startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Medium widget: "Today's question is ready"

struct QuestionReadyWidget: Widget {
    let kind = "QuestionReadyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            QuestionReadyView(entry: entry)
                .containerBackground(for: .widget) { plumBackground }
        }
        .configurationDisplayName("Today's Question")
        .description("Shows today's memory question and how your companion is doing.")
        .supportedFamilies([.systemMedium])
    }
}

private struct QuestionReadyView: View {
    let entry: PetEntry
    private var d: PetWidgetData { entry.data }

    var body: some View {
        HStack(spacing: 14) {
            companionImage()
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .padding(6)
                .foregroundStyle(.white)
                .background(Circle().fill(.white.opacity(0.14)))

            VStack(alignment: .leading, spacing: 5) {
                Text("Today's question")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.wThistle)

                Text(d.todaysQuestion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 2)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(index < d.hungerLevel ? Color.wHeart : .white.opacity(0.22))
                        }
                    }
                    Spacer()
                    Label("\(d.dayStreak)", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.wAmber)
                }
            }
        }
        .padding(4)
    }
}

// MARK: - Small widget: day streak

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            StatSmallView(systemIcon: "flame.fill",
                          value: "\(entry.data.dayStreak)",
                          label: "day streak",
                          tint: .wAmber)
                .containerBackground(for: .widget) { lavenderBackground }
        }
        .configurationDisplayName("Day Streak")
        .description("Your current daily check-in streak.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Small widget: memories saved

struct MemoriesSavedWidget: Widget {
    let kind = "MemoriesSavedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            StatSmallView(systemIcon: "heart.fill",
                          value: "\(entry.data.memoriesSavedTotal)",
                          label: "memories saved",
                          tint: .wHeart)
                .containerBackground(for: .widget) { lavenderBackground }
        }
        .configurationDisplayName("Memories Saved")
        .description("Total memories saved so far.")
        .supportedFamilies([.systemSmall])
    }
}

private struct StatSmallView: View {
    let systemIcon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemIcon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.7)))

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.wBlackberry)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.wNinja)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Local hex helper

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

#Preview("Question Ready", as: .systemMedium) {
    QuestionReadyWidget()
} timeline: {
    PetEntry(date: .now, data: .placeholder)
}

#Preview("Streak", as: .systemSmall) {
    StreakWidget()
} timeline: {
    PetEntry(date: .now, data: .placeholder)
}

#Preview("Memories Saved", as: .systemSmall) {
    MemoriesSavedWidget()
} timeline: {
    PetEntry(date: .now, data: .placeholder)
}
