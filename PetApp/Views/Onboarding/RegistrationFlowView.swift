
//
//  RegistrationFlowView.swift
//  PetApp
//
//  Full MemoMe registration: Get Started → Permissions → Step 1 personal
//  details → Step 2 accessibility → Step 3 choose companion → Welcome popup.
//  Each step has a back button; accessibility choices bind straight to
//  AppSettings, and the companion is persisted on completion.
//
 
import SwiftUI
import SwiftData
 
struct RegistrationFlowView: View {
    let onComplete: () -> Void
    let onCancel: () -> Void
 
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var permissions = PermissionsManager()
 
    enum Step: Int {
        case getStarted, permissions, personal, accessibility, companion
    }
 
    @State private var step: Step = .getStarted
    @State private var showWelcome = false
 
    // Drafts collected across steps.
    @State private var fullName = ""
    @State private var dob = Calendar.current.date(from: DateComponents(year: 1955, month: 1, day: 1)) ?? Date()
    @State private var profile = CompanionProfile()
 
    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()
 
            content
                .animation(.easeInOut(duration: 0.2), value: step)
 
            if showWelcome {
                WelcomePopup(profile: profile) { commitAndFinish() }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut, value: showWelcome)
    }
 
    @ViewBuilder
    private var content: some View {
        switch step {
        case .getStarted:
            GetStartedStep(fullName: $fullName, onBack: goBack) { advance() }
        case .permissions:
            PermissionsStep(permissions: permissions, onBack: goBack) { advance() }
        case .personal:
            PersonalDetailsStep(fullName: $fullName, dob: $dob,
                                onBack: goBack) { advance() }
        case .accessibility:
            AccessibilityStep(settings: settings, onBack: goBack) { advance() }
        case .companion:
            CompanionStep(profile: $profile, onBack: goBack) {
                showWelcome = true
            }
        }
    }
 
    // MARK: - Navigation
 
    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        }
    }
 
    private func goBack() {
        if step == .getStarted {
            onCancel()
        } else if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        }
    }
 
    private func commitAndFinish() {
        settings.name = fullName.trimmingCharacters(in: .whitespaces)
        settings.birthday = dob
        companionStore.save(profile)
 
        let owner = currentOrNewUser()
        let companion = profile.makeCompanion(owner: owner)
        modelContext.insert(companion)
        try? modelContext.save()
        companionStore.clearDraft()
 
        onComplete()
    }
 
    /// Finds (or creates) the local SwiftData `User` anchor matching the
    /// authenticated account, so the new Companion has something to attach
    /// to. Returns nil if there's no signed-in id yet (shouldn't happen at
    /// this point in the flow, but this keeps onboarding from crashing if it does).
    private func currentOrNewUser() -> User? {
        guard let id = auth.userId else { return nil }
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let user = User(id: id)
        modelContext.insert(user)
        return user
    }
}
 
// MARK: - Shared step scaffold
 
/// Common chrome for a registration step: back button, optional "Step x / 3"
/// label, scrollable content, and an optional primary footer button.
struct StepScaffold<Content: View>: View {
    var stepNumber: Int? = nil          // 1...3, or nil for pre-steps
    var title: String
    var subtitle: String? = nil
    let onBack: () -> Void
    var primaryTitle: String? = nil
    var primaryEnabled: Bool = true
    var onPrimary: (() -> Void)? = nil
    @ViewBuilder var content: Content
 
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppColor.ninja)
                    }
                    .accessibilityLabel("Back")
                    Spacer()
                }
 
                if let stepNumber {
                    StepProgress(total: 3, current: stepNumber)
                    Text("Step \(stepNumber) / 3")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
 
                Text(LocalizedStringKey(title))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(.title3)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
 
            ScrollView {
                content
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)
            }
 
            if let primaryTitle, let onPrimary {
                Button(action: onPrimary) { Text(primaryTitle) }
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
                    .disabled(!primaryEnabled)
                    .opacity(primaryEnabled ? 1 : 0.5)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
            }
        }
    }
}
 

































