
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
    @EnvironmentObject private var auth: AuthViewModel
    @Query private var companions: [Companion]
    @Query private var allMemories: [Memory]
 
    @State private var promptIndex = DailyPrompts.todayIndex
    @State private var showDailyQuestion = false
    @State private var showRecording = false
    @State private var showEditCompanion = false

    /// The question resolved by the daily-question sheet, then answered in the
    /// recorder. `pendingQuestion` holds it until the sheet has dismissed so the
    /// recorder is only presented once the sheet is fully gone.
    @State private var resolvedQuestion: String?
    @State private var pendingQuestion: String?

    /// Bumped to play the Rive companion's Feed / Talk one-shot animations.
    @State private var feedToken = 0
    @State private var talkToken = 0

    private let amber = Color(hex: "#F7C873")
    private let amberSoft = Color(hex: "#FBE6BE")
    private let amberText = Color(hex: "#C77A22")
    private let heart = Color(hex: "#E0555F")
 
    /// The signed-in user's companion. Scoped by owner so a different account
    /// never sees a previous user's pet (SwiftData is local and not per-user).
    private var companion: Companion? {
        companions.first { $0.owner?.id == auth.userId }
    }

    /// Memories belonging to the signed-in user. Matched by the stamped
    /// `ownerId`, falling back to the companion's owner, and including legacy
    /// memories that predate owner stamping (ownerId == nil) so nothing the
    /// user recorded ever disappears from their history.
    private var userMemories: [Memory] {
        let uid = auth.userId?.uuidString
        return allMemories.filter { memory in
            if let owner = memory.ownerId { return owner == uid }
            return memory.companion?.owner?.id == auth.userId || memory.companion == nil
        }
    }
 
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
        .sheet(isPresented: $showDailyQuestion, onDismiss: {
            // Promote to the recorder only after the question sheet has fully
            // dismissed, so the two presentations don't collide.
            if let pendingQuestion {
                resolvedQuestion = pendingQuestion
                self.pendingQuestion = nil
                showRecording = true
            }
        }) {
            DailyQuestionView(
                prompt: DailyPrompts.anchors[promptIndex],
                onRecord: { question in
                    pendingQuestion = question
                    showDailyQuestion = false
                },
                onCancel: { showDailyQuestion = false }
            )
        }
        .memoryRecorder(isPresented: $showRecording,
                        question: resolvedQuestion,
                        languageCode: settings.language.speechLocaleIdentifier) { saved in
            persistMemory(saved)
        }
        .recordingRecovery(languageCode: settings.language.speechLocaleIdentifier) { saved in
            persistMemory(saved)
        }
        .task { syncWidget() }
        .onChange(of: companions.count) { _, _ in syncWidget() }
        .onChange(of: allMemories.count) { _, _ in syncWidget() }
    }

    /// Persists a just-recorded memory, stamped with the current user so it
    /// shows in Archive. Logs on failure instead of failing silently.
    private func persistMemory(_ saved: SavedMemory) {
        do {
            _ = try saved.persist(in: modelContext,
                                  companion: companion,
                                  ownerId: auth.userId?.uuidString)
            syncWidget()
        } catch {
            print("[Memory] Failed to save memory to Archive: \(error.localizedDescription)")
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
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: Date())
    }
 
    // MARK: - Stat cards (food bar + memory streak)
 
    private var statCards: some View {
        HStack(spacing: Spacing.md) {
            statCard(background: AppColor.ninja.opacity(0.14),
                     accent: AppColor.textPrimary,
                     badgeBackground: .white.opacity(0.85),
                     title: "Happiness Level",
                     badge: {
                         Text(moodEmoji).font(.title3)
                     },
                     value: {
                         HStack(spacing: 6) {
                             ForEach(0..<3, id: \.self) { index in
                                 Image(systemName: index < filledHearts ? "heart.fill" : "heart")
                                     .foregroundStyle(index < filledHearts ? heart : heart.opacity(0.3))
                             }
                         }
                         .font(.body)
                     })
            .accessibilityLabel("Happiness, \(filledHearts) of 3")

            statCard(background: amberSoft,
                     accent: amberText,
                     badgeBackground: amber.opacity(0.45),
                     title: "Memory Streak",
                     badge: {
                         Text("❤️‍🔥").font(.body)
                     },
                     value: {
                         HStack(alignment: .firstTextBaseline, spacing: 3) {
                             Text("\(streakDays)").font(.title3.weight(.bold))
                             Text(streakDays == 1 ? "Day" : "Days").font(.subheadline.weight(.semibold))
                         }
                         .foregroundStyle(amberText)
                     })
            .accessibilityLabel("Memory streak, \(streakDays) days")
        }
    }
 
    /// Food-bar hearts, derived from how long since the companion was cared for.
    private var filledHearts: Int { companion?.hungerHearts ?? 3 }

    /// Face reflecting the happiness level: 3 hearts happy, 2 neutral, 1 sad.
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
        let days = Set(userMemories.filter { !$0.isDeleted }.map { calendar.startOfDay(for: $0.date) })
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
 
    /// A home stat card: a badge in a circle, a title, then a value row pinned
    /// to the bottom. The `Spacer` bottom-aligns the value across both cards, so
    /// the two cards stay visually symmetric regardless of value height.
    private func statCard<Badge: View, Value: View>(
        background: Color,
        accent: Color,
        badgeBackground: Color,
        title: String,
        @ViewBuilder badge: () -> Badge,
        @ViewBuilder value: () -> Value
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                badge()
                    .frame(width: 30, height: 30)
                    .background(badgeBackground, in: Circle())
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: Spacing.xs)
            value()
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(Spacing.sm)
        .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
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
                                  color: companionColor,
                                  feedToken: feedToken)
                        .frame(width: 300, height: 300)
                        .clipped()
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
 
            Text(LocalizedStringKey(DailyPrompts.anchors[promptIndex].anchor))
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
                    promptIndex = (promptIndex + 1) % DailyPrompts.anchors.count
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
        WidgetSync.update(companion: companion, name: settings.name, memories: userMemories)
    }
 
    // MARK: - Record
 
    private var recordButton: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                showDailyQuestion = true
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
        .environmentObject(AppSettings())
        .modelContainer(for: [Companion.self, Memory.self, User.self], inMemory: true)
}
 
