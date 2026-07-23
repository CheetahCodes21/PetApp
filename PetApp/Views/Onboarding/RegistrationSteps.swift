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
            SVGImageView(name: "RegistrationMascot")
                .frame(width: 200, height: 200)
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
        PasswordPolicy.isValid(password)
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
 
            Text(LocalizedStringKey(text))
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
    /// Drives the staggered entrance + header pulse.
    @State private var appeared = false
    @State private var pulse = false
 
    private var allGranted: Bool {
        AppPermission.allCases.allSatisfy { permissions.state(for: $0) == .granted }
    }
 
    /// Distinct accent per permission so the cards feel lively.
    private func tint(_ permission: AppPermission) -> Color {
        switch permission {
        case .microphone:    return Color(hex: "#5A9BD4")
        case .camera:        return Color(hex: "#E4739A")
        case .photos:        return Color(hex: "#5EAE7E")
        case .notifications: return Color(hex: "#F2A65A")
        }
    }
 
    var body: some View {
        StepScaffold(title: "A few permissions",
                     subtitle: "MemoMe only asks for what it needs to help you.",
                     onBack: onBack,
                     primaryTitle: "Continue",
                     onPrimary: onNext) {
            VStack(spacing: Spacing.md) {
                header
 
                ForEach(Array(AppPermission.allCases.enumerated()), id: \.element) { index, permission in
                    row(permission)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8)
                            .delay(0.08 * Double(index) + 0.15), value: appeared)
                }
 
                allowButton
                    .padding(.top, Spacing.xs)
            }
        }
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
 
    // MARK: Header — pulsing privacy badge
 
    private var header: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [AppColor.ninja.opacity(0.35), .clear],
                                   center: .center, startRadius: 2, endRadius: 70)
                )
                .frame(width: 150, height: 150)
                .scaleEffect(pulse ? 1.12 : 0.9)
 
            Circle()
                .stroke(AppColor.ninja.opacity(0.25), lineWidth: 1.5)
                .frame(width: pulse ? 108 : 88, height: pulse ? 108 : 88)
                .opacity(pulse ? 0 : 0.9)
 
            Circle()
                .fill(LinearGradient(colors: [AppColor.ninja, AppColor.blackberry],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 76, height: 76)
                .shadow(color: AppColor.blackberry.opacity(0.3), radius: 12, y: 6)
 
            Image(systemName: allGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(height: 150)
        .accessibilityHidden(true)
    }
 
    // MARK: Permission card
 
    private func row(_ permission: AppPermission) -> some View {
        let state = permissions.state(for: permission)
        let accent = tint(permission)
        return HStack(spacing: Spacing.md) {
            Image(systemName: permission.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    LinearGradient(colors: [accent, accent.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: accent.opacity(0.35), radius: 6, y: 3)
 
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(permission.title))
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text(LocalizedStringKey(permission.explanation))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
 
            Spacer(minLength: Spacing.xs)
 
            statusIcon(state)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(state == .granted ? accent.opacity(0.5) : AppColor.textSecondary.opacity(0.12),
                        lineWidth: state == .granted ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: state)
    }
 
    @ViewBuilder
    private func statusIcon(_ state: PermissionState) -> some View {
        switch state {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColor.success)
                .transition(.scale.combined(with: .opacity))
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.red.opacity(0.7))
                .transition(.scale.combined(with: .opacity))
        case .notDetermined:
            Circle()
                .strokeBorder(AppColor.textSecondary.opacity(0.3),
                              style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 22, height: 22)
        }
    }
 
    // MARK: Allow button
 
    private var allowButton: some View {
        Button {
            Task {
                requesting = true
                await permissions.requestAll()
                requesting = false
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                if requesting {
                    ProgressView().tint(.white)
                    Text("Requesting…")
                } else if allGranted {
                    Image(systemName: "checkmark")
                    Text("All set")
                } else {
                    Image(systemName: "sparkles")
                    Text("Allow access")
                }
            }
        }
        .buttonStyle(FilledButtonStyle(background: allGranted ? AppColor.success : AppColor.ninja))
        .disabled(requesting || allGranted)
        .animation(.easeInOut, value: allGranted)
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
                LabeledField(label: "Full name", text: Binding(
                    get: { fullName },
                    set: { fullName = $0.filter { $0.isLetter || $0.isWhitespace } }
                ), textContentType: .name)
 
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
                            SpeechService.shared.speakLocalized(
                                "Hello, this is how I will read your memories.",
                                language: settings.language,
                                speed: settings.voiceSpeed)
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
        Text(LocalizedStringKey(title))
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
                sectionLabel("\(profile.kind == .pet ? "Feed" : "Water") every \(profile.careFrequencyDays) day\(profile.careFrequencyDays == 1 ? "" : "s")")
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
        Text(LocalizedStringKey(text))
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppColor.textPrimary)
    }
 
    private func toggleLabel(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
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
            Text(LocalizedStringKey(title))
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
