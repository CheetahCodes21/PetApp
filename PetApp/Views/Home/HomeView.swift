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
        .sheet(isPresented: $showEditCompanion) {
            if let companion {
                EditCompanionSheet(companion: companion)
            }
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
                    icon("face.smiling", tint: AppColor.ninja)
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
                (PetSpecies(rawValue: companion.petSpeciesRaw) ?? .default).image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
            case .plant:
                LottieView(name: (PlantSpecies(rawValue: companion.plantSpeciesRaw) ?? .default).lottieName)
                    .frame(width: 180, height: 180)
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
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(AppColor.ninja, in: Circle())
                }
                .accessibilityLabel("Feed companion")
                Text("feed")
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

// MARK: - Edit companion sheet

private struct EditCompanionSheet: View {
    let companion: Companion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: CompanionKind = .pet
    @State private var petSpecies: PetSpecies = .default
    @State private var plantSpecies: PlantSpecies = .default
    @State private var colorVariant = CompanionColorOption.default.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        companionPreview

                        LabeledField(label: "Companion name", text: $name)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Type")
                                .font(.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            Picker("Type", selection: $kind) {
                                ForEach(CompanionKind.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(kind == .pet ? "Choose your pet" : "Choose your plant")
                                .font(.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            speciesPicker
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
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
                        }

                        // Age — read-only (how old the companion is).
                        HStack {
                            Text("Age")
                                .font(.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            Text(ageText)
                                .font(.body)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.ninja.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Age, \(ageText)")
                    }
                    .padding(Spacing.lg)
                }
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
                kind = companion.kind
                petSpecies = PetSpecies(rawValue: companion.petSpeciesRaw) ?? .default
                plantSpecies = PlantSpecies(rawValue: companion.plantSpeciesRaw) ?? .default
                colorVariant = companion.colorVariant
            }
        }
    }

    private var previewColor: Color {
        (CompanionColorOption(rawValue: colorVariant) ?? .default).color
    }

    /// Live preview that updates as the user changes type / colour.
    private var companionPreview: some View {
        ZStack {
            Circle()
                .fill(previewColor.opacity(0.2))
                .frame(width: 150, height: 150)
            Circle()
                .stroke(previewColor, lineWidth: 4)
                .frame(width: 150, height: 150)

            Group {
                switch kind {
                case .pet:
                    petSpecies.image
                        .resizable()
                        .scaledToFit()
                case .plant:
                    LottieView(name: plantSpecies.lottieName)
                }
            }
            .frame(width: 110, height: 110)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var speciesPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                if kind == .pet {
                    ForEach(PetSpecies.allCases) { species in
                        speciesCell(name: species.displayName,
                                    isSelected: petSpecies == species) {
                            species.image.resizable().scaledToFit()
                        } action: {
                            petSpecies = species
                        }
                    }
                } else {
                    ForEach(PlantSpecies.allCases) { species in
                        speciesCell(name: species.displayName,
                                    isSelected: plantSpecies == species) {
                            LottieView(name: species.lottieName)
                        } action: {
                            plantSpecies = species
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func speciesCell<Art: View>(name: String,
                                        isSelected: Bool,
                                        @ViewBuilder art: () -> Art,
                                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                art().frame(width: 60, height: 60)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? previewColor.opacity(0.18) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? previewColor : .clear, lineWidth: 2)
            )
        }
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var ageText: String {
        let days = Calendar.current.dateComponents([.day],
                                                   from: companion.createdAt,
                                                   to: Date()).day ?? 0
        switch days {
        case ..<1:  return "Born today"
        case 1:     return "1 day old"
        default:    return "\(days) days old"
        }
    }

    private func save() {
        companion.name = name
        companion.kind = kind
        companion.petSpeciesRaw = petSpecies.rawValue
        companion.plantSpeciesRaw = plantSpecies.rawValue
        companion.colorVariant = colorVariant
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Companion.self, Memory.self, User.self], inMemory: true)
}
