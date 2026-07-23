//
//  EditPetView.swift
//  PetApp
//
//  The full "Edit Pet" experience: edit name / care frequency / sick + vibrate
//  toggles, a "Change Pet" roster (grid → confirmation), and a "Changes Saved"
//  confirmation. Changing the companion keeps memories, streak, and level.
//

import SwiftUI
import SwiftData

// MARK: - A selectable companion (pet species or plant)

struct CompanionOption: Identifiable, Hashable {
    let kind: CompanionKind
    let pet: PetSpecies?
    let plant: PlantSpecies?

    var id: String { pet.map { "pet.\($0.rawValue)" } ?? plant.map { "plant.\($0.rawValue)" } ?? "" }
    var displayName: String { pet?.displayName ?? plant?.displayName ?? "" }

    /// Every companion that has real art: the animated Rive cat, the
    /// image-backed animals, and the Lottie plant(s).
    static let all: [CompanionOption] =
        PetSpecies.allCases.map { CompanionOption(kind: .pet, pet: $0, plant: nil) }
        + PlantSpecies.allCases.map { CompanionOption(kind: .plant, pet: nil, plant: $0) }

    @ViewBuilder
    func art(color: SwiftUI.Color = AppColor.ninja) -> some View {
        if let pet {
            if pet.isAnimated {
                RiveCatView(hearts: 3, isSick: false, color: color)
            } else {
                pet.image.resizable().scaledToFit()
            }
        } else if let plant {
            if plant.isAnimated {
                RivePlantView(color: color)
            } else {
                LottieView(name: plant.lottieName)
            }
        }
    }
}

// MARK: - Edit Pet

struct EditPetView: View {
    let companion: Companion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var careDays = 7
    @State private var sick = false
    @State private var vibrate = false
    @State private var colorVariant = CompanionColorOption.default.rawValue
    @State private var showChangePet = false
    @State private var showSaved = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        preview
                        nameField
                        colourPicker
                        careFrequency
                        toggles
                        actions
                        significantAction
                    }
                    .padding(Spacing.lg)
                }

                if showSaved { ChangesSavedOverlay() }
            }
            .navigationTitle("Edit Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.title3.weight(.semibold))
                            .foregroundStyle(AppColor.ninja)
                    }
                    .accessibilityLabel("Back")
                }
            }
            .onAppear {
                name = companion.name
                careDays = max(1, companion.careFrequencyDays)
                sick = companion.becomesUnwellIfNotFed
                vibrate = companion.vibrateWhenFed
                colorVariant = companion.colorVariant
            }
            .fullScreenCover(isPresented: $showChangePet) {
                ChangePetView(companion: companion) {
                    showChangePet = false
                    confirmSaved()
                }
            }
        }
    }

    // MARK: Sections

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColor.thistle.opacity(0.6))
            companionArt
                .frame(width: 180, height: 180)
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var companionArt: some View {
        switch companion.kind {
        case .pet:
            let species = PetSpecies(rawValue: companion.petSpeciesRaw) ?? .default
            if species.isAnimated {
                RiveCatView(hearts: 3, isSick: false, color: companionColor)
            } else {
                species.image.resizable().scaledToFit().frame(width: 200, height: 200)
            }
        case .plant:
            let plant = PlantSpecies(rawValue: companion.plantSpeciesRaw) ?? .default
            if plant.isAnimated {
                RivePlantView(color: companionColor)
            } else {
                LottieView(name: plant.lottieName)
            }
        }
    }

    private var companionColor: SwiftUI.Color {
        (CompanionColorOption(rawValue: colorVariant) ?? .default).color
    }

    private var colourPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Colour")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            HStack(spacing: Spacing.md) {
                ForEach(CompanionColorOption.allCases) { option in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { colorVariant = option.rawValue }
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(AppColor.textPrimary,
                                            lineWidth: colorVariant == option.rawValue ? 3 : 0)
                                    .padding(2)
                            )
                    }
                    .accessibilityLabel(option.rawValue)
                    .accessibilityAddTraits(colorVariant == option.rawValue ? [.isSelected] : [])
                }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("My Name", systemImage: "pencil")
                .labelStyle(TrailingIconLabel())
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            TextField("Name", text: $name)
                .font(.title3)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColor.ninja.opacity(0.4), lineWidth: 1.5))
        }
    }

    private var careFrequency: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Care Frequency", systemImage: "pencil")
                .labelStyle(TrailingIconLabel())
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text("\(careDays) Day\(careDays == 1 ? "" : "s")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity)
            Slider(value: Binding(get: { Double(careDays) },
                                  set: { careDays = Int($0.rounded()) }),
                   in: 1...15, step: 1)
                .tint(AppColor.ninja)
        }
    }

    private var toggles: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $sick) {
                Text("I will be sick\nif not fed timely")
                    .font(.headline).foregroundStyle(AppColor.textPrimary)
            }
            .tint(AppColor.ninja)
            .padding(.vertical, Spacing.sm)

            Divider().overlay(AppColor.textSecondary.opacity(0.2))

            Toggle(isOn: $vibrate) {
                Text("Vibrate when fed")
                    .font(.headline).foregroundStyle(AppColor.textPrimary)
            }
            .tint(AppColor.ninja)
            .padding(.vertical, Spacing.sm)
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.md) {
            Button { save() } label: { Text("Save Changes") }
                .buttonStyle(FilledButtonStyle(background: AppColor.ninja))

            Button { dismiss() } label: {
                Text("Cancel").foregroundStyle(Color(hex: "#C0504D"))
            }
            .buttonStyle(OutlinedButtonStyle(border: Color(hex: "#C0504D")))
        }
        .padding(.top, Spacing.sm)
    }

    private var significantAction: some View {
        VStack(spacing: Spacing.sm) {
            Text("Significant Action")
                .font(.headline).foregroundStyle(Color(hex: "#C0504D"))
            Text("Changing your pet might reset your current progress with your pet and cannot be undone. However your journal will be as it is on the archive.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Button { showChangePet = true } label: {
                Text("Change Pet").foregroundStyle(Color(hex: "#C0504D"))
            }
            .buttonStyle(OutlinedButtonStyle(border: Color(hex: "#C0504D")))
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#C0504D").opacity(0.5), lineWidth: 1.5))
    }

    // MARK: Actions

    private func save() {
        companion.name = name
        companion.careFrequencyDays = careDays
        companion.becomesUnwellIfNotFed = sick
        companion.vibrateWhenFed = vibrate
        companion.colorVariant = colorVariant
        try? modelContext.save()
        confirmSaved()
    }

    private func confirmSaved() {
        withAnimation { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            dismiss()
        }
    }
}

// MARK: - Change Pet (roster grid)

struct ChangePetView: View {
    let companion: Companion
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Filter: String, CaseIterable { case all = "All", animals = "Animals", plants = "Plants" }
    @State private var filter: Filter = .all
    @State private var selected: CompanionOption?

    private let columns = [GridItem(.flexible(), spacing: Spacing.md),
                           GridItem(.flexible(), spacing: Spacing.md)]

    private var options: [CompanionOption] {
        switch filter {
        case .all:     return CompanionOption.all
        case .animals: return CompanionOption.all.filter { $0.kind == .pet }
        case .plants:  return CompanionOption.all.filter { $0.kind == .plant }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Companions")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppColor.textPrimary)

                        filterChips

                        LazyVGrid(columns: columns, spacing: Spacing.md) {
                            ForEach(options) { option in
                                gridCell(option)
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle("Change Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.title3.weight(.semibold))
                            .foregroundStyle(AppColor.ninja)
                    }
                    .accessibilityLabel("Back")
                }
            }
            .sheet(item: $selected) { option in
                ChangePetConfirmView(option: option) {
                    apply(option)
                }
                .presentationDetents([.large])
            }
        }
    }

    private var filterChips: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Filter.allCases, id: \.self) { f in
                Button { filter = f } label: {
                    Text(f.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(filter == f ? AppColor.ninja : AppColor.thistle.opacity(0.5),
                                    in: Capsule())
                        .foregroundStyle(filter == f ? .white : AppColor.textPrimary)
                }
            }
            Spacer()
        }
    }

    private func gridCell(_ option: CompanionOption) -> some View {
        Button { selected = option } label: {
            VStack(spacing: Spacing.xs) {
                option.art()
                    .frame(height: 90)
                    .frame(maxWidth: .infinity)
                Text(option.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(AppColor.blackberry, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .accessibilityLabel(option.displayName)
    }

    private func apply(_ option: CompanionOption) {
        companion.kind = option.kind
        if let pet = option.pet { companion.petSpeciesRaw = pet.rawValue }
        if let plant = option.plant { companion.plantSpeciesRaw = plant.rawValue }
        // Memories, streak, and lastFedAt are intentionally untouched.
        selected = nil
        dismiss()
        onChanged()
    }
}

// MARK: - Change Pet confirmation

private struct ChangePetConfirmView: View {
    let option: CompanionOption
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Spacer()

                ZStack(alignment: .bottomTrailing) {
                    option.art().frame(width: 160, height: 160)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppColor.ninja)
                        .background(Circle().fill(.white))
                }

                (Text("You're going to change your pet to a ")
                    .foregroundStyle(AppColor.textPrimary)
                 + Text(option.displayName).foregroundStyle(AppColor.ninja).bold()
                 + Text(".").foregroundStyle(AppColor.textPrimary))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    bullet("heart.fill", "Your memories and progress will be kept.")
                    bullet("face.smiling.fill", "Feeding streak and level will continue.")
                    bullet("camera.fill", "You can change again anytime in settings.")
                }
                .padding(.horizontal, Spacing.sm)

                Spacer()

                VStack(spacing: Spacing.md) {
                    Button { onConfirm() } label: { Text("Confirm Change") }
                        .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
                    Button { dismiss() } label: { Text("Cancel").foregroundStyle(AppColor.textPrimary) }
                        .buttonStyle(OutlinedButtonStyle())
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(AppColor.ninja)
                .frame(width: 40, height: 40)
                .background(AppColor.ninja.opacity(0.15), in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
        }
    }
}

// MARK: - Changes Saved overlay

struct ChangesSavedOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [AppColor.ninja, AppColor.blackberry],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 90, height: 90)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Changes Saved")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Helper

/// A label with the icon after the title.
private struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon.font(.subheadline).foregroundStyle(AppColor.ninja)
        }
    }
}
