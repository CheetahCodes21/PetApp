//
//  RegistrationSteps.swift
//  PetApp
//
//  The individual steps used by RegistrationFlowView.
//
 
import SwiftUI
 
// MARK: - Get started
 
struct GetStartedStep: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Binding var fullName: String
    let onBack: () -> Void
    let onNext: () -> Void
 
    private enum Mode { case choose, email }
    @State private var mode: Mode = .choose
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private let passwordRegex =
    "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*()_+\\-={}\\[\\]|:;\"'<>,.?/~`]).{8,}$"
    @State private var working = false
    @State private var error: String?
 
    var body: some View {
        StepScaffold(
            title: mode == .choose ? "Get started" : "Sign up with email",
            subtitle: mode == .choose
                ? "Create your MemoMe account."
                : "We'll use this to keep your memories safe.",
            onBack: {
                if mode == .email { mode = .choose; error = nil } else { onBack() }
            }
        ) {
            if mode == .choose { chooseContent } else { emailContent }
        }
    }
 
    private var chooseContent: some View {
        VStack(spacing: Spacing.lg) {
            Text("🐤")
                .font(.system(size: 88))
                .padding(.top, Spacing.md)
                .accessibilityHidden(true)
 
            VStack(spacing: Spacing.md) {
                AppleSignInButton { result in handleApple(result) }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
 
                Button("Sign up with email") { mode = .email }
                    .buttonStyle(OutlinedButtonStyle())
            }
 
            if let error {
                Text(error).font(.subheadline).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
 
            Text("You can change these details later.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
 
    private var emailContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            LabeledField(label: "Email", placeholder: "name@email.com",
                         text: $email, keyboard: .emailAddress,
                         textContentType: .emailAddress)
            LabeledField(label: "Password", text: $password,
                         isSecure: true, textContentType: .newPassword)
            LabeledField(
                label: "Confirm Password",
                text: $confirmPassword,
                isSecure: true,
                textContentType: .newPassword
            )
            
            VStack(alignment: .leading, spacing: 6) {

                validationRow(password.count >= 8,
                              "At least 8 characters")

                validationRow(password.range(of: "[A-Z]", options: .regularExpression) != nil,
                              "One uppercase letter")

                validationRow(password.range(of: "[a-z]", options: .regularExpression) != nil,
                              "One lowercase letter")

                validationRow(password.range(of: "[0-9]", options: .regularExpression) != nil,
                              "One number")

                validationRow(password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil,
                              "One special character")

            }
            .font(.subheadline)
 
            if let error {
                Text(error).font(.subheadline).foregroundStyle(.red)
            }
 
            Button(action: createAccount) {
                if working {
                    ProgressView().tint(.white)
                } else {
                    Text("Create account")
                }
            }
            .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
            .disabled(!canSubmit || working)
            .opacity(canSubmit ? 1 : 0.5)
        }
    }
 
    private func createAccount() {

        guard isValidEmail else {
            error = "Please enter a valid email address."
            return
        }

        guard isValidPassword else {
            error = """
    Password must contain:
    • At least 8 characters
    • One uppercase letter
    • One lowercase letter
    • One number
    • One special character
    """
            return
        }

        guard password == confirmPassword else {
            error = "Passwords do not match."
            return
        }

        working = true
        error = nil

        Task {
            do {
                try await auth.signUpWithEmail(
                    email: email,
                    password: password,
                    fullName: fullName
                )

                working = false
                onNext()

            } catch {
                working = false
                self.error = (error as? LocalizedError)?.errorDescription
                    ?? "We couldn't create your account. Please try again."
            }
        }
    }
 
    private func handleApple(_ result: Result<AppleCredential, Error>) {
        switch result {
        case .success(let credential):
            if fullName.isEmpty, !credential.fullName.isEmpty {
                fullName = credential.fullName
            }
            Task {
                do {
                    try await auth.signInWithApple(credential)
                    onNext()
                } catch {
                    self.error = (error as? LocalizedError)?.errorDescription
                        ?? "Apple sign-in failed. Please try again."
                }
            }
        case .failure:
            break
        }
    }
    private var isValidEmail: Bool {
        let regex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex)
            .evaluate(with: email)
    }

    private var isValidPassword: Bool {
        NSPredicate(format: "SELF MATCHES %@", passwordRegex)
            .evaluate(with: password)
    }

    private var canSubmit: Bool {
        isValidEmail &&
        isValidPassword &&
        password == confirmPassword
    }
    
    @ViewBuilder
    private func validationRow(_ valid: Bool, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: valid ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(valid ? .green : .gray)

            Text(text)
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}
 
// MARK: - Permissions
 
struct PermissionsStep: View {
    @ObservedObject var permissions: PermissionsManager
    let onBack: () -> Void
    let onNext: () -> Void
 
    @State private var requesting = false
 
    var body: some View {
        StepScaffold(title: "A few permissions",
                     subtitle: "MemoMe only asks for what it needs to help you.",
                     onBack: onBack,
                     primaryTitle: "Continue",
                     onPrimary: onNext) {
            VStack(spacing: Spacing.md) {
                ForEach(AppPermission.allCases) { permission in
                    row(permission)
                }
 
                Button {
                    Task {
                        requesting = true
                        await permissions.requestAll()
                        requesting = false
                    }
                } label: {
                    Text(requesting ? "Requesting…" : "Allow access")
                }
                .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
                .disabled(requesting)
                .padding(.top, Spacing.xs)
            }
        }
    }
 
    private func row(_ permission: AppPermission) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: permission.systemImage)
                .font(.title2)
                .foregroundStyle(AppColor.ninja)
                .frame(width: 40)
 
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text(permission.explanation)
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
 
            Spacer()
 
            statusIcon(permissions.state(for: permission))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColor.textSecondary.opacity(0.15), lineWidth: 1)
        )
    }
 
    @ViewBuilder
    private func statusIcon(_ state: PermissionState) -> some View {
        switch state {
        case .granted:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColor.success)
        case .denied:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red.opacity(0.7))
        case .notDetermined:
            Image(systemName: "circle").foregroundStyle(AppColor.textSecondary.opacity(0.4))
        }
    }
}
 
// MARK: - Step 1: personal details
 
struct PersonalDetailsStep: View {
    @Binding var fullName: String
    @Binding var dob: Date
    let onBack: () -> Void
    let onNext: () -> Void
 
    var body: some View {
        StepScaffold(stepNumber: 1,
                     title: "Personal details",
                     subtitle: "Just a couple of things about you.",
                     onBack: onBack,
                     primaryTitle: "Continue",
                     primaryEnabled: !fullName.trimmingCharacters(in: .whitespaces).isEmpty,
                     onPrimary: onNext) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                LabeledField(label: "Full name", text: $fullName,
                             textContentType: .name)
 
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Date of birth")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    DatePicker("Date of birth", selection: $dob,
                               in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "en_US"))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
 
// MARK: - Step 2: accessibility
 
struct AccessibilityStep: View {
    @ObservedObject var settings: AppSettings
    let onBack: () -> Void
    let onNext: () -> Void
 
    var body: some View {
        StepScaffold(stepNumber: 2,
                     title: "Accessibility settings",
                     subtitle: "Set things up so MemoMe is comfortable to use.",
                     onBack: onBack,
                     primaryTitle: "Continue",
                     onPrimary: onNext) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                labeled("Font size") {
                    FontSizePicker(selection: $settings.textSize)
                }
                labeled("Theme") {
                    SegmentedTheme(selection: $settings.theme)
                }

                labeled("Voice speed") {
                    VStack(spacing: Spacing.sm) {
                        Slider(value: $settings.voiceSpeed, in: 0...1)
                            .tint(AppColor.ninja)
                        Button {
                            SpeechService.shared.speak(
                                "Hello, this is how I will read your memories.",
                                speed: settings.voiceSpeed,
                                languageCode: settings.language.rawValue)
                        } label: {
                            Label("Test voice", systemImage: "speaker.wave.2.fill")
                                .font(.headline)
                                .foregroundStyle(AppColor.ninja)
                        }
                    }
                }
 
                labeled("Language") {
                    LanguageMenu(selection: $settings.language)
                }
 
                Toggle(isOn: $settings.textToVoice) {
                    controlLabel("Text-to-voice")
                }
                .tint(AppColor.ninja)
            }
        }
    }
 
    private func labeled<V: View>(_ title: String, @ViewBuilder _ control: () -> V) -> some View {
        HStack {
            controlLabel(title)
            Spacer()
            control()
        }
    }
 
    private func controlLabel(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppColor.textPrimary)
    }
}
 
// MARK: - Step 3: choose companion
 
struct CompanionStep: View {
    @Binding var profile: CompanionProfile
    let onBack: () -> Void
    let onNext: () -> Void
 
    var body: some View {
        StepScaffold(stepNumber: 3,
                     title: "Choose your MemoMe",
                     subtitle: "Pick a companion and make it yours.",
                     onBack: onBack,
                     primaryTitle: "Create my MemoMe",
                     primaryEnabled: !profile.name.trimmingCharacters(in: .whitespaces).isEmpty,
                     onPrimary: onNext) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                preview
 
                // Pet or plant
                SegmentedKind(selection: $profile.kind)
 
                // Colour customisation
                sectionLabel("Colour")
                colorPicker
 
                // Name
                LabeledField(label: "Companion name", text: $profile.name)
 
                // Care frequency
                sectionLabel("Feed every \(profile.careFrequencyDays) day\(profile.careFrequencyDays == 1 ? "" : "s")")
                Slider(
                    value: Binding(
                        get: { Double(profile.careFrequencyDays) },
                        set: { profile.careFrequencyDays = Int($0.rounded()) }
                    ),
                    in: 1...15, step: 1
                )
                .tint(AppColor.ninja)
 
                Toggle(isOn: $profile.sickIfNotFed) {
                    toggleLabel("Show as sick if not fed in time")
                }
                .tint(AppColor.ninja)
 
                Toggle(isOn: $profile.vibrateWhenFed) {
                    toggleLabel("Vibrate phone when fed")
                }
                .tint(AppColor.ninja)
            }
        }
    }
 
    private var preview: some View {
        ZStack {
            Circle()
                .fill(profile.color.opacity(0.2))
                .frame(width: 140, height: 140)
            Circle()
                .stroke(profile.color, lineWidth: 4)
                .frame(width: 140, height: 140)
            profile.preview
                .frame(width: 96, height: 96)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
 
    private var colorPicker: some View {
        HStack(spacing: Spacing.md) {
            ForEach(CompanionColorOption.allCases) { option in
                let isSelected = profile.colorOption == option
                Button {
                    profile.colorOption = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle().stroke(AppColor.textPrimary,
                                            lineWidth: isSelected ? 3 : 0)
                                .padding(2)
                        )
                }
                .accessibilityLabel(option.id.capitalized)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
 
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppColor.textPrimary)
    }
 
    private func toggleLabel(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(AppColor.textPrimary)
    }
}
 
// MARK: - Welcome popup
 
struct WelcomePopup: View {
    let profile: CompanionProfile
    let onFinish: () -> Void
 
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
 
            VStack(spacing: Spacing.lg) {
                profile.preview
                    .frame(width: 110, height: 110)
 
                Text("Welcome to MemoMe!")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.textPrimary)
 
                Text(greeting)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.textSecondary)
 
                Button("Let's go", action: onFinish)
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
            }
            .padding(Spacing.xl)
            .background(AppColor.snow,
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, Spacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }
 
    private var greeting: String {
        let name = profile.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty
            ? "Your companion is ready. Let's start remembering together."
            : "\(name) is ready to help you remember, one day at a time."
    }
}
 
// MARK: - Shared inline controls
 
private struct FontSizePicker: View {
    @Binding var selection: AppTextSize
 
    var body: some View {
        HStack(spacing: 0) {
            cell(.small, size: 14)
            cell(.medium, size: 19)
            cell(.large, size: 24)
        }
        .background(AppColor.ninja.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
 
    private func cell(_ value: AppTextSize, size: CGFloat) -> some View {
        Button { selection = value } label: {
            Text("A")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(selection == value ? .white : AppColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selection == value ? AppColor.ninja : .clear)
                )
        }
    }
}
 
private struct SegmentedTheme: View {
    @Binding var selection: AppTheme
 
    var body: some View {
        HStack(spacing: 0) {
            seg("Light", .light)
            seg("Dark", .dark)
        }
        .background(AppColor.ninja.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
 
    private func seg(_ title: String, _ value: AppTheme) -> some View {
        Button { selection = value } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(selection == value ? AppColor.ninja : AppColor.textSecondary)
                .padding(.vertical, Spacing.sm)
                .frame(width: 70)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selection == value ? Color.white : .clear)
                )
        }
    }
}
 
private struct SegmentedKind: View {
    @Binding var selection: CompanionKind
 
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CompanionKind.allCases) { kind in
                Button { selection = kind } label: {
                    Label(kind.title, systemImage: kind.systemImage)
                        .font(.headline)
                        .foregroundStyle(selection == kind ? .white : AppColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selection == kind ? AppColor.ninja : .clear)
                        )
                }
            }
        }
        .background(AppColor.ninja.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
 
private struct LanguageMenu: View {
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
            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
 
