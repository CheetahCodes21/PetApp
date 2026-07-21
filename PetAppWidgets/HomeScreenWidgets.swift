//
//  HomeScreenWidgets.swift
//  PetAppWidgets
//
//  Home Screen widgets. Unlike the Lock Screen accessory widget, these
//  render in full color (unless the person turns on Tinted appearance in
//  Home Screen editing, which the system handles automatically). Uses the
//  same AppColor palette as the app — copy Theme.swift's color values into
//  this target too (widget extensions don't share code with the app unless
//  the file is added to both targets in Xcode's File Inspector).
//

import WidgetKit
import SwiftUI

// MARK: - Medium widget: "Today's question is ready"

struct QuestionReadyWidget: Widget {
    let kind = "QuestionReadyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            QuestionReadyView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "#2E1A3D"), Color(hex: "#1B0F26")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Today's Question")
        .description("Shows when today's memory question is ready to answer.")
        .supportedFamilies([.systemMedium])
    }
}

private struct QuestionReadyView: View {
    let entry: PetEntry

    private var progress: Double {
        guard entry.data.memoriesGoalThisMonth > 0 else { return 0 }
        return min(1, Double(entry.data.memoriesThisMonth) / Double(entry.data.memoriesGoalThisMonth))
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(entry.data.companionAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.15)))

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's question is ready")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(entry.data.todaysQuestion)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }

                ProgressView(value: progress)
                    .tint(Color(hex: "#B99BE0"))

                Text("\(entry.data.memoriesThisMonth) of \(entry.data.memoriesGoalThisMonth) memories this month")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
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
            StatSmallView(
                icon: Image(entry.data.companionAssetName),
                systemIcon: nil,
                value: "\(entry.data.dayStreak)",
                label: "day streak",
                tint: Color(hex: "#6B4E9E")
            )
            .containerBackground(.white, for: .widget)
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
            StatSmallView(
                icon: nil,
                systemIcon: "heart.fill",
                value: "\(entry.data.memoriesSavedTotal)",
                label: "memories saved",
                tint: Color(hex: "#6B4E9E")
            )
            .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Memories Saved")
        .description("Total memories saved so far.")
        .supportedFamilies([.systemSmall])
    }
}

private struct StatSmallView: View {
    var icon: Image?
    var systemIcon: String?
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let icon { icon.resizable().scaledToFit() }
                else if let systemIcon { Image(systemName: systemIcon).resizable().scaledToFit().foregroundStyle(tint) }
            }
            .frame(width: 28, height: 28)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#221B2B"))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(hex: "#6E6A78"))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
