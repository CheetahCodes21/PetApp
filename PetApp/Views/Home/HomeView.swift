//
//  HomeView.swift
//  PetApp
//
//  The main screen: greeting, week strip, food bar + memory streak, the
//  companion display, the daily prompt, a feed button, and tap-to-record.
//  Reads the persisted SwiftData `Companion` and `Memory` models.
//

import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var companions: [Companion]
    @Query private var allMemories: [Memory]

    @State private var promptIndex = DailyPrompts.todayIndex
    @State private var showRecordSoon = false
    @State private var showEditCompanion = false

    private let amber = Color(hex: "#F7C873")
    private let amberSoft = Color(hex: "#FBE6BE")
    private let amberText = Color(hex: "#C77A22")
    private let heart = Color(hex: "#E0555F")

    private var companion: Companion? { companions.first }

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    WeekStrip()
                    statCards
                    companionCard
                    promptRow
                    recordButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xl)
            }
        }
        .alert("Recording coming soon", isPresented: $showRecordSoon) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The voice recording flow is on its way. You'll be able to tap and speak your memory here.")
        }
        .sheet(isPresented: $showEditCompanion) {
            if let companion {
                EditCompanionSheet(companion: companion)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Welcome back!")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text(monthYear)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: Date())
    }

    // MARK: - Stat cards (food bar + memory streak)

    private var statCards: some View {
        HStack(spacing: Spacing.md) {
            statCard(background: AppColor.purple.opacity(0.14)) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    icon("face.smiling", tint: AppColor.purple)
                    Text("Food bar")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "heart.fill")
                                .foregroundStyle(index < filledHearts ? heart : Color.gray.opacity(0.35))
                        }
                    }
                    .font(.title3)
                }
            }
            .accessibilityLabel("Food bar, \(filledHearts) of 3")

            statCard(background: amberSoft) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    icon("flame.fill", tint: amberText, bg: amber.opacity(0.4))
                    Text("Memory Streak")
                        .font(.headline)
                        .foregroundStyle(amberText)
                    Text("\(streakDays) Days")
                        .font(.title.weight(.bold))
                        .foregroundStyle(amberText)
                }
            }
            .accessibilityLabel("Memory streak, \(streakDays) days")
        }
    }

    private var filledHearts: Int {
        switch companion?.currentHungerState {
        case "hungry":     return 2
        case "veryHungry": return 1
        case "good":       return 3
        default:           return 3
        }
    }

    private var streakDays: Int { companion?.streakCount ?? 0 }

    private func statCard<Content: View>(background: Color,
                                         @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(Spacing.md)
            .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func icon(_ system: String, tint: Color, bg: Color? = nil) -> some View {
        Image(systemName: system)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background((bg ?? Color.white.opacity(0.7)), in: Circle())
    }

    // MARK: - Companion display

    private var companionCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(companionColor.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(companionColor.opacity(0.35), lineWidth: 2)
                )

            companionArt
                .frame(maxWidth: .infinity)
                .frame(height: 220)

            if companion != nil {
                Button {
                    showEditCompanion = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                .padding(Spacing.md)
                .accessibilityLabel("Edit companion")
            }
        }
        .frame(height: 240)
    }

    @ViewBuilder
    private var companionArt: some View {
        if let companion {
            switch companion.kind {
            case .pet:
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundStyle(companionColor)
            case .plant:
                LottieView(name: "FlowerIdleDisplay")
                    .frame(width: 180, height: 180)
            }
        } else {
            Text("🐣").font(.system(size: 120))
        }
    }

    private var companionColor: Color {
        guard let variant = companion?.colorVariant,
              let option = CompanionColorOption(rawValue: variant) else {
            return AppColor.purple
        }
        return option.color
    }

    // MARK: - Prompt row (feed + question + refresh)

    private var promptRow: some View {
        HStack(spacing: Spacing.md) {
            VStack(spacing: 4) {
                Button {
                    withAnimation { feed() }
                } label: {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(AppColor.purple, in: Circle())
                }
                .accessibilityLabel("Feed companion")
                Text("feed")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Text(DailyPrompts.all[promptIndex])
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppColor.textSecondary.opacity(0.15), lineWidth: 1)
                )

            Button {
                withAnimation {
                    promptIndex = (promptIndex + 1) % DailyPrompts.all.count
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("New question")
        }
    }

    private func feed() {
        guard let companion else { return }
        companion.lastFedAt = Date()
        companion.currentHungerState = "good"
        try? modelContext.save()
        if companion.vibrateWhenFed {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - Record

    private var recordButton: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                showRecordSoon = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(AppColor.plum, in: Circle())
                    .shadow(color: AppColor.plum.opacity(0.3), radius: 10, y: 4)
            }
            .accessibilityLabel("Tap to record a memory")
            Text("tap to record")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Week strip

private struct WeekStrip: View {
    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 2) {
                    Text(format(day, "EEE"))
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                    Text(format(day, "d"))
                        .font(.headline)
                        .foregroundStyle(isToday ? AppColor.purple : AppColor.textPrimary)
                    Text(format(day, "MMM"))
                        .font(.caption2)
                        .foregroundStyle(AppColor.textSecondary)
                    Circle()
                        .fill(isToday ? amber : .clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private let amber = Color(hex: "#E8912E")

    private func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}

// MARK: - Edit companion sheet

private struct EditCompanionSheet: View {
    let companion: Companion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorVariant = CompanionColorOption.default.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.surface.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    LabeledField(label: "Companion name", text: $name)

                    Text("Colour")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    HStack(spacing: Spacing.md) {
                        ForEach(CompanionColorOption.allCases) { option in
                            Button {
                                colorVariant = option.rawValue
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().stroke(AppColor.textPrimary,
                                                             lineWidth: colorVariant == option.rawValue ? 3 : 0).padding(2))
                            }
                            .accessibilityLabel(option.rawValue)
                        }
                    }

                    Spacer()
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("Edit companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                name = companion.name
                colorVariant = companion.colorVariant
            }
        }
    }

    private func save() {
        companion.name = name
        companion.colorVariant = colorVariant
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Companion.self, Memory.self, User.self], inMemory: true)
}
