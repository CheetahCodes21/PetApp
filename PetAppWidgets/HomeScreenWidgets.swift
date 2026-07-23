///
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
 
/// Loads the companion image the app wrote into the shared App Group container,
/// if one exists (the real static artwork — dog/cow/rabbit/goldfish).
private func companionUIImage() -> UIImage? {
    guard let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id) else { return nil }
    return UIImage(contentsOfFile: container.appendingPathComponent("companion.png").path)
}
 
/// The companion's chosen recolour, matching the app's colour picker
/// (CompanionColorOption) — defaults to purple, same as in-app.
private func companionTint(_ data: PetWidgetData) -> Color {
    guard let hex = data.companionColorHex else { return Color(hex: "#6B4E9E") }
    return Color(hex: hex)
}
 
/// A time-of-day greeting.
private func greeting(_ date: Date) -> String {
    switch Calendar.current.component(.hour, from: date) {
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<22: return "Good evening"
    default:      return "Hello"
    }
}
 
// MARK: - Companion avatar (photo when available, else the mood face)
 
private struct CompanionAvatar: View {
    let data: PetWidgetData
    var size: CGFloat = 64
 
    var body: some View {
        Group {
            if let ui = companionUIImage(), !data.companionAssetName.isEmpty {
                // Real static artwork (dog, cow, rabbit, goldfish) — already
                // rendered in its fixed colour, no tinting needed.
                Image(uiImage: ui)
                    .resizable().scaledToFit()
            } else if data.companionKind != nil {
                // Animated companions (the Rive cat, or any plant) have no
                // exported photo, but do have a still "idle" illustration
                // bundled with the widget. It's a fully coloured picture,
                // not a monochrome template, so a flat tint would flatten
                // all its shading into one solid colour — instead, blend in
                // the chosen colour's hue/saturation while keeping each
                // pixel's original luminance, so shading and outlines stay
                // visible and it reads as e.g. "pink cat" rather than a
                // silhouette. (The masked eyes/nose/stars will shift colour
                // too, since this is one flattened image, not separate
                // layers like the in-app Rive version.)
                let assetName = data.companionKind == "plant" ? "Plant idle" : "Cat Idle"
                ZStack {
                    Image(assetName).resizable().scaledToFit()
                    companionTint(data).blendMode(.color)
                }
                .compositingGroup()
                .mask(Image(assetName).resizable().scaledToFit())
            } else {
                Text(data.moodEmoji)
                    .font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
    }
}
 
private struct HeartsRow: View {
    let filled: Int          // 0...3 mood hearts
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < filled ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(i < filled ? Color.wHeart : Color.wHeart.opacity(0.3))
            }
        }
    }
}
 
/// A rounded speech-bubble shape with a small tail pointing left, toward
/// whatever avatar sits beside it (used to make the daily question read as
/// something the companion is "saying").
private struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 16
    var tailSize: CGFloat = 9
 
    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(x: rect.minX + tailSize, y: rect.minY,
                                 width: rect.width - tailSize, height: rect.height)
        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)
 
        let tailY = bubbleRect.minY + min(cornerRadius + tailSize, bubbleRect.height / 2)
        path.move(to: CGPoint(x: bubbleRect.minX, y: tailY - tailSize))
        path.addLine(to: CGPoint(x: bubbleRect.minX - tailSize, y: tailY))
        path.addLine(to: CGPoint(x: bubbleRect.minX, y: tailY + tailSize))
        path.closeSubpath()
        return path
    }
}
 
private struct SpeechBubble: View {
    let text: String
    var fill: Color = .white
    var textColor: Color = .wBlackberry
 
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(textColor)
            .lineLimit(3)
            .minimumScaleFactor(0.85)
            .padding(.vertical, 12)
            .padding(.leading, 9 + 10)   // tailSize + normal inset
            .padding(.trailing, 10)
            .fixedSize(horizontal: false, vertical: true)
            .background(SpeechBubbleShape().fill(fill))
    }
}
 
// MARK: - Companion widget (small + medium) — the flagship
 
struct CompanionWidget: Widget {
    let kind = "CompanionWidget"
 
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            CompanionView(entry: entry)
                .containerBackground(for: .widget) { lavenderBackground }
        }
        .configurationDisplayName("Your Companion")
        .description("Your companion’s mood, your streak, and today’s question.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
 
private struct CompanionView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PetEntry
    private var d: PetWidgetData { entry.data }
 
    var body: some View {
        if d.isSignedOut {
            emptyState
        } else if family == .systemSmall {
            small
        } else {
            medium
        }
    }
 
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                CompanionAvatar(data: d, size: 56)
                Spacer()
                Label("\(d.dayStreak)", systemImage: "flame.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.wAmber)
            }
            Spacer(minLength: 2)
            Text(d.companionName ?? "Companion")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.wBlackberry)
                .lineLimit(1)
            HeartsRow(filled: d.moodHearts ?? 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
 
    private var medium: some View {
        HStack(spacing: 14) {
            CompanionAvatar(data: d, size: 92)
 
            VStack(alignment: .leading, spacing: 5) {
                Text("\(greeting(entry.date)), \(d.userFirstName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.wNinja)
                    .lineLimit(1)
 
                Text(d.companionName ?? "Your companion")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.wBlackberry)
                    .lineLimit(1)
 
                HeartsRow(filled: d.moodHearts ?? 3)
 
                Spacer(minLength: 2)
 
                HStack(spacing: 12) {
                    stat(icon: "flame.fill", value: "\(d.dayStreak)", label: "streak", tint: .wAmber)
                    stat(icon: "heart.fill", value: "\(d.memoriesSavedTotal)", label: "memories", tint: .wHeart)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
 
    private func stat(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2).foregroundStyle(tint)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(Color.wBlackberry)
            Text(label).font(.caption2).foregroundStyle(Color.wNinja)
        }
    }
 
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🐾").font(.system(size: family == .systemSmall ? 34 : 44))
            Text("Open MemoMe to meet your companion")
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.wNinja)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
 
// MARK: - Medium widget: "Today's question is ready"
 
struct QuestionReadyWidget: Widget {
    let kind = "QuestionReadyWidget"
 
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            QuestionReadyView(entry: entry)
                .containerBackground(for: .widget) { lavenderBackground }
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
        if d.isSignedOut {
            emptyState
        } else {
            HStack(spacing: 14) {
                CompanionAvatar(data: d, size: 92)
 
                VStack(alignment: .leading, spacing: 8) {
                    SpeechBubble(text: d.todaysQuestion, fill: .wSnow)
 
                    Spacer(minLength: 2)
 
                    HStack(spacing: 12) {
                        HeartsRow(filled: d.moodHearts ?? 3)
                        if d.dayStreak > 0 {
                            stat(icon: "flame.fill", value: "\(d.dayStreak)", label: "day streak", tint: .wAmber)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
 
    private func stat(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2).foregroundStyle(tint)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(Color.wBlackberry)
            Text(label).font(.caption2).foregroundStyle(Color.wNinja)
        }
    }
 
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🐾").font(.system(size: 44))
            Text("Open MemoMe to meet your companion")
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.wNinja)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
 
#Preview("Companion", as: .systemMedium) {
    CompanionWidget()
} timeline: {
    PetEntry(date: .now, data: .placeholder)
}
 
#Preview("Companion small", as: .systemSmall) {
    CompanionWidget()
} timeline: {
    PetEntry(date: .now, data: .placeholder)
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
