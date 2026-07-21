//
//  SettingsView.swift
//  PetApp
//
//  User settings (mockup): name, birthday, notifications, text-to-voice,
//  text size, theme, language, and info rows. Text size, theme, and language
//  are wired to AppSettings and applied app-wide from the root.
//

import SwiftUI

struct SettingsView: View {
    var showsBack: Bool = true

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingName = false
    @State private var editingBirthday = false
    @State private var nameDraft = ""
    @State private var confirmSignOut = false

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    header
                    card
                    Button(role: .destructive) {
                        confirmSignOut = true
                    } label: {
                        Text("Sign out")
                    }
                    .buttonStyle(OutlinedButtonStyle())
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if showsBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppColor.purple)
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
        .alert("My name", isPresented: $editingName) {
            TextField("Your name", text: $nameDraft)
            Button("Save") { settings.name = nameDraft }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $editingBirthday) {
            BirthdayEditor(birthday: $settings.birthday)
        }
        .confirmationDialog("Sign out of MemoMe?",
                            isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your memories stay safely saved. You can sign back in anytime.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColor.purple.opacity(0.25))
                    .frame(width: 120, height: 120)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }
            Text("Settings")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(.top, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Settings")
    }

    // MARK: - Settings card

    private var card: some View {
        VStack(spacing: 0) {
            // My name
            SettingRow {
                DisclosureContent(title: "My name", subtitle: settings.name.isEmpty ? "Tap to add" : settings.name)
            } trailing: {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundStyle(AppColor.textPrimary)
            } action: {
                nameDraft = settings.name
                editingName = true
            }

            Divider().overlay(AppColor.textSecondary.opacity(0.25))

            // My birthday
            SettingRow {
                DisclosureContent(title: "My birthday", subtitle: formattedBirthday)
            } trailing: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColor.textSecondary)
            } action: {
                editingBirthday = true
            }

            Divider().overlay(AppColor.textSecondary.opacity(0.25))

            // Lock screen notification
            ToggleRow(title: "Lock screen notification",
                      isOn: $settings.lockScreenNotifications)

            Divider().overlay(AppColor.textSecondary.opacity(0.25))

            // Text-to-voice
            ToggleRow(title: "Text-to-voice", isOn: $settings.textToVoice)

            Divider().overlay(AppColor.textSecondary.opacity(0.25))

            // Text size
            HStack {
                Text("Text size")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                TextSizeSelector(selection: $settings.textSize)
            }
            .padding(.vertical, Spacing.md)

            Divider().overlay(AppColor.textSecondary.opacity(0.25))

            // Theme
            HStack {
                Text("Theme")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                ThemeSelector(selection: $settings.theme)
            }
            .padding(.vertical, Spacing.md)

            Divider().overlay(AppColor.textSecondary.opacity(0.25))

            // Language
            HStack {
                Text("Language")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                LanguageSelector(selection: $settings.language)
            }
            .padding(.vertical, Spacing.md)

            Divider().overlay(AppColor.textSecondary.opacity(0.25))

            // About / Version info
            SettingRow {
                Text("About / Version Info")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
            } trailing: {
                Image(systemName: "chevron.right").foregroundStyle(AppColor.textSecondary)
            } action: { }

            Divider().overlay(AppColor.textSecondary.opacity(0.25))

            // Help & Support
            SettingRow {
                Text("Help & Support")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
            } trailing: {
                Image(systemName: "chevron.right").foregroundStyle(AppColor.textSecondary)
            } action: { }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(AppColor.purple.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var formattedBirthday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: settings.birthday)
    }
}

// MARK: - Row building blocks

private struct SettingRow<Content: View, Trailing: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var trailing: Trailing
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                content
                Spacer()
                trailing
            }
            .contentShape(Rectangle())
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
    }
}

private struct DisclosureContent: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
        }
        .tint(AppColor.purple)
        .padding(.vertical, Spacing.md)
    }
}

// MARK: - Text size selector (3 levels)

private struct TextSizeSelector: View {
    @Binding var selection: AppTextSize

    var body: some View {
        HStack(spacing: 0) {
            cell(.small, size: 16)
            cell(.medium, size: 22)
            cell(.large, size: 28)
        }
        .background(AppColor.purple.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Text size")
    }

    private func cell(_ value: AppTextSize, size: CGFloat) -> some View {
        Button {
            selection = value
        } label: {
            Text("A")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(selection == value ? .white : AppColor.textPrimary)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selection == value ? AppColor.purple : .clear)
                )
        }
        .accessibilityLabel(label(for: value))
        .accessibilityAddTraits(selection == value ? [.isSelected] : [])
    }

    private func label(for value: AppTextSize) -> String {
        switch value {
        case .small: return "Small text"
        case .medium: return "Medium text"
        case .large: return "Large text"
        }
    }
}

// MARK: - Theme selector

private struct ThemeSelector: View {
    @Binding var selection: AppTheme

    var body: some View {
        HStack(spacing: 0) {
            segment("Light", value: .light)
            segment("Dark", value: .dark)
        }
        .background(AppColor.purple.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func segment(_ title: String, value: AppTheme) -> some View {
        Button {
            selection = value
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(selection == value ? AppColor.purple : AppColor.textSecondary)
                .padding(.vertical, Spacing.sm)
                .frame(width: 80)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selection == value ? Color.white : .clear)
                )
        }
        .accessibilityAddTraits(selection == value ? [.isSelected] : [])
    }
}

// MARK: - Language selector

private struct LanguageSelector: View {
    @Binding var selection: AppLanguage

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    selection = language
                } label: {
                    if selection == language {
                        Label(language.displayName, systemImage: "checkmark")
                    } else {
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(selection.shortLabel)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityLabel("Language, currently \(selection.displayName)")
    }
}

// MARK: - Birthday editor

private struct BirthdayEditor: View {
    @Binding var birthday: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("My birthday", selection: $birthday,
                           in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .padding()
                Spacer()
            }
            .navigationTitle("My birthday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        SettingsView().environmentObject(AppSettings())
    }
}
