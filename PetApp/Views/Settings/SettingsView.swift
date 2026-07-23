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
    @State private var editingEmail = false
    @State private var emailDraft = ""
    @State private var editingPassword = false
    @State private var passwordDraft = ""
    @State private var confirmPasswordDraft = ""
    @State private var confirmDelete = false
    @State private var accountError: String?
    @State private var showPrivacyPolicy = false
 
    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()
 
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
 
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Text("Delete account")
                            .foregroundStyle(.red)
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
                            .foregroundStyle(AppColor.ninja)
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
        .alert("My name", isPresented: $editingName) {
            TextField("Your name", text: Binding(
                get: { nameDraft },
                set: { nameDraft = $0.filter { $0.isLetter || $0.isWhitespace } }
            ))
            Button("Save") { settings.name = nameDraft.trimmingCharacters(in: .whitespaces) }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $editingBirthday) {
            BirthdayEditor(birthday: $settings.birthday)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .confirmationDialog("Sign out of MemoMe?",
                            isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your memories stay safely saved. You can sign back in anytime.")
        }
        .alert("Edit email", isPresented: $editingEmail) {
            TextField("name@email.com", text: $emailDraft)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button("Save") { Task { await saveEmail() } }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Edit password", isPresented: $editingPassword) {
            SecureField("New password", text: $passwordDraft)
            SecureField("Confirm new password", text: $confirmPasswordDraft)
            Button("Save") { Task { await savePassword() } }
                .disabled(passwordDraft.isEmpty || passwordDraft != confirmPasswordDraft)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(PasswordPolicy.requirementsSummary) Both fields must match.")
        }
        .confirmationDialog("Delete your account?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes your account. You'll be signed out.")
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { accountError != nil },
                                    set: { if !$0 { accountError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(accountError ?? "")
        }
    }
 
    // MARK: - Account actions
 
    private func saveEmail() async {
        do {
            try await auth.updateEmail(to: emailDraft)
        } catch {
            accountError = (error as? LocalizedError)?.errorDescription
                ?? "We couldn't update your email. That address may already be in use."
        }
    }
 
    private func savePassword() async {
        guard passwordDraft == confirmPasswordDraft else {
            accountError = "Those passwords don't match. Please try again."
            return
        }
        guard PasswordPolicy.isValid(passwordDraft) else {
            accountError = "Password must contain: \(PasswordPolicy.requirementsSummary)"
            return
        }
        do {
            try await auth.updatePassword(to: passwordDraft)
            passwordDraft = ""
            confirmPasswordDraft = ""
        } catch {
            accountError = (error as? LocalizedError)?.errorDescription
                ?? "We couldn't update your password. Please try again."
        }
    }
 
    private func deleteAccount() async {
        do {
            try await auth.deleteAccount()
        } catch {
            accountError = (error as? LocalizedError)?.errorDescription
                ?? "We couldn't delete your account. Please try again."
        }
    }
 
    // MARK: - Header
 
    private var header: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColor.ninja.opacity(0.25))
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
 
            // Email
            SettingRow {
                DisclosureContent(title: "Email",
                                  subtitle: auth.email.isEmpty ? "Not set" : auth.email)
            } trailing: {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundStyle(AppColor.textPrimary)
            } action: {
                emailDraft = auth.email
                editingEmail = true
            }
 
            Divider().overlay(AppColor.textSecondary.opacity(0.25))
 
            // Password
            SettingRow {
                DisclosureContent(title: "Password", subtitle: "••••••••")
            } trailing: {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundStyle(AppColor.textPrimary)
            } action: {
                passwordDraft = ""
                confirmPasswordDraft = ""
                editingPassword = true
            }
 
            Divider().overlay(AppColor.textSecondary.opacity(0.25))
 
            // Lock screen notification
            ToggleRow(title: "Lock screen notification",
                      isOn: $settings.lockScreenNotifications)
 
            Divider().overlay(AppColor.textSecondary.opacity(0.25))
 
            // Text-to-voice
            ToggleRow(title: "Text-to-voice", isOn: $settings.textToVoice)
 
            Divider().overlay(AppColor.textSecondary.opacity(0.25))
 
            // Voice speed
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Voice speed")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Slider(value: $settings.voiceSpeed, in: 0...1)
                    .tint(AppColor.ninja)
                Button {
                    SpeechService.shared.speakLocalized(
                        "Hello, this is how I will read your memories.",
                        language: settings.language,
                        speed: settings.voiceSpeed)
                } label: {
                    Label("Test voice", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ninja)
                }
            }
            .padding(.vertical, Spacing.md)
 
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
 
            Divider().overlay(AppColor.textSecondary.opacity(0.25))
 
            // Privacy Policy
            SettingRow {
                Text("Privacy Policy")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
            } trailing: {
                Image(systemName: "chevron.right").foregroundStyle(AppColor.textSecondary)
            } action: { showPrivacyPolicy = true }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(AppColor.ninja.opacity(0.18),
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
        .tint(AppColor.ninja)
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
        .background(AppColor.ninja.opacity(0.12),
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
                        .fill(selection == value ? AppColor.ninja : .clear)
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
        .background(AppColor.ninja.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
 
    private func segment(_ title: String, value: AppTheme) -> some View {
        Button {
            selection = value
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(selection == value ? AppColor.ninja : AppColor.textSecondary)
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
