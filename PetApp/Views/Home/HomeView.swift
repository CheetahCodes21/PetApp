
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
    @EnvironmentObject private var settings: AppSettings
    @Query private var companions: [Companion]
    @Query private var allMemories: [Memory]
 
    @State private var promptIndex = DailyPrompts.todayIndex
    @State private var showRecording = false
    @State private var showEditCompanion = false
    /// Bumped to play the Rive cat's Feed / Talk one-shot animations.
    @State private var feedToken = 0
    @State private var talkToken = 0
 
    private let amber = Color(hex: "#F7C873")
    private let amberSoft = Color(hex: "#FBE6BE")
    private let amberText = Color(hex: "#C77A22")
    private let heart = Color(hex: "#E0555F")
 
    private var companion: Companion? { companions.first }
 
    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()
 
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
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
        .fullScreenCover(isPresented: $showEditCompanion) {
            if let companion {
                EditPetView(companion: companion)
            }
        }
        .memoryRecorder(isPresented: $showRecording, question: DailyPrompts.all[promptIndex]) { saved in
            _ = try? saved.persist(in: modelContext, companion: companion)
        }
        .recordingRecovery { saved in
            _ = try? saved.persist(in: modelContext, companion: companion)
        }
        .task {
            ensureCompanion()
            syncWidget()
        }
        .onChange(of: companions.count) { _, _ in syncWidget() }
        .onChange(of: allMemories.count) { _, _ in syncWidget() }
    }
 
    /// Guarantees there's a companion to show and edit. If onboarding never
    /// created one on this device (e.g. an existing user just signed in),
    /// seed a sensible default the user can then edit.
    private func ensureCompanion() {
        guard companions.isEmpty else { return }
        let seeded = Companion(
            kind: .pet,
            colorVariant: CompanionColorOption.default.rawValue,
            name: "My friend",
            careFrequencyLabel: "Once a week",
            becomesUnwellIfNotFed: false,
            vibrateWhenFed: true
        )
        modelContext.insert(seeded)
        try? modelContext.save()
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
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: Date())
    }
 
    // MARK: - Stat cards (food bar + memory streak)
 
    private var statCards: some View {
        HStack(spacing: Spacing.md) {
            statCard(background: AppColor.ninja.opacity(0.14)) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(moodEmoji)
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.7), in: Circle())
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
 
    /// Food-bar hearts, derived from how long since the companion was cared for.
    private var filledHearts: Int { companion?.hungerHearts ?? 3 }

    /// Face reflecting the food bar: 3 hearts happy, 2 neutral, 1 sad.
    private var moodEmoji: String {
        switch filledHearts {
        case 3:  return "😊"
        case 2:  return "😐"
        default: return "😢"
        }
    }
 
    private var careVerb: String { companion?.careVerb ?? "Feed" }
    private var careIcon: String { companion?.kind == .plant ? "drop.fill" : "fork.knife" }

    /// Streak = consecutive days (ending today) that have at least one memory.
    private var streakDays: Int {
        let calendar = Calendar.current
        let days = Set(allMemories.filter { !$0.isDeleted }.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
 
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
                .frame(height: 300)
 
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
        .frame(height: 320)
    }
 
    @ViewBuilder
    private var companionArt: some View {
        if let companion {
            switch companion.kind {
            case .pet:
                let species = PetSpecies(rawValue: companion.petSpeciesRaw) ?? .default
                if species.isAnimated {
                    RiveCatView(hearts: companion.hungerHearts,
                                isSick: companion.isSick,
                                color: companionColor,
                                feedToken: feedToken,
                                talkToken: talkToken)
                        .frame(width: 300, height: 300)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { talkToken += 1 }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Tap \(companion.name) to say hi")
                } else {
                    species.image.resizable().scaledToFit().frame(width: 260, height: 260)
                }
            case .plant:
                let plant = PlantSpecies(rawValue: companion.plantSpeciesRaw) ?? .default
                if plant.isAnimated {
                    RivePlantView(hearts: companion.hungerHearts,
                                  isSick: companion.isSick,
                                  color: companionColor,
                                  feedToken: feedToken,
                                  talkToken: talkToken)
                        .frame(width: 300, height: 300)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { talkToken += 1 }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Tap \(companion.name) to say hi")
                } else {
                    LottieView(name: plant.lottieName)
                        .frame(width: 220, height: 220)
                }
            }
        } else {
            Text("🐣").font(.system(size: 120))
        }
    }
 
    private var companionColor: Color {
        guard let variant = companion?.colorVariant,
              let option = CompanionColorOption(rawValue: variant) else {
            return AppColor.ninja
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
                    Image(systemName: careIcon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(AppColor.ninja, in: Circle())
                }
                .accessibilityLabel(careVerb)
                Text(LocalizedStringKey(careVerb))
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
 
            Text(LocalizedStringKey(DailyPrompts.all[promptIndex]))
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
        feedToken += 1   // play the cat's Feed animation
        if companion.vibrateWhenFed {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        syncWidget()
    }
 
    private func syncWidget() {
        WidgetSync.update(companion: companion, name: settings.name, memories: allMemories)
    }
 
    // MARK: - Record
 
    private var recordButton: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                showRecording = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(AppColor.blackberry, in: Circle())
                    .shadow(color: AppColor.blackberry.opacity(0.3), radius: 10, y: 4)
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
 
 
#Preview {
    HomeView()
        .modelContainer(for: [Companion.self, Memory.self, User.self], inMemory: true)
}
 
