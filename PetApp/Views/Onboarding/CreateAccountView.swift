//
//  CreateAccountView.swift
//  PetApp
//
//  Multi-step account creation for new users (mockups 3–6):
//  name & email → password → choose companion → account created.
//  Self-contained: owns the draft and step state, reports back via callbacks.
//

import SwiftUI

struct CreateAccountView: View {
    let onComplete: (SignUpDraft) -> Void
    let onCancel: () -> Void

    private enum Step: Int, CaseIterable {
        case details, password, companion, done
    }

    @State private var step: Step = .details
    @State private var draft = SignUpDraft()

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                switch step {
                case .details:
                    DetailsStep(firstName: $draft.firstName, email: $draft.email)
                case .password:
                    PasswordStep(password: $draft.password)
                case .companion:
                    CompanionStep(selection: $draft.companion)
                case .done:
                    AccountCreatedStep(firstName: draft.firstName)
                }

                Spacer(minLength: Spacing.md)

                primaryButton
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Header (back + progress + step caption)

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                if step != .done {
                    Button(action: goBack) {
                        Label("Back", systemImage: "chevron.left")
                            .font(.headline)
                            .foregroundStyle(AppColor.purple)
                    }
                    .accessibilityLabel("Back")
                }
                Spacer()
            }

            if step != .done {
                StepProgress(total: 3, current: step.rawValue + 1)
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
    }

    private var caption: String {
        switch step {
        case .details: return "Create account — step 1 of 3"
        case .password: return "Create password — step 2 of 3"
        case .companion: return "Choose your companion — step 3 of 3"
        case .done: return ""
        }
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        Button(action: advance) {
            Text(primaryTitle)
        }
        .buttonStyle(FilledButtonStyle(background: AppColor.purple))
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.5)
    }

    private var primaryTitle: String {
        switch step {
        case .details, .password: return "Continue"
        case .companion:
            let name = draft.companion?.displayName.lowercased() ?? "companion"
            return "Meet my \(name)"
        case .done: return "Choose my companion"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .details:
            return !draft.firstName.trimmingCharacters(in: .whitespaces).isEmpty
                && draft.email.contains("@")
        case .password:
            return PasswordRules.isValid(draft.password)
        case .companion:
            return draft.companion != nil
        case .done:
            return true
        }
    }

    // MARK: - Navigation

    private func advance() {
        switch step {
        case .details: step = .password
        case .password: step = .companion
        case .companion: step = .done
        case .done: onComplete(draft)
        }
    }

    private func goBack() {
        switch step {
        case .details: onCancel()
        case .password: step = .details
        case .companion: step = .password
        case .done: break
        }
    }
}

// MARK: - Step 1: details

private struct DetailsStep: View {
    @Binding var firstName: String
    @Binding var email: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Let's get to know you")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Just two details to begin.")
                    .font(.title3)
                    .foregroundStyle(AppColor.textSecondary)
            }

            LabeledField(label: "Your first name", text: $firstName,
                         textContentType: .givenName)
            LabeledField(label: "Your email", placeholder: "name@email.com",
                         text: $email, keyboard: .emailAddress,
                         textContentType: .emailAddress)

            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppColor.purple)
                Text("A family member can help you set this up. You can change everything later.")
                    .font(.body)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.purple.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Step 2: password

private struct PasswordStep: View {
    @Binding var password: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Create a password")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Pick something easy for you to remember.")
                    .font(.title3)
                    .foregroundStyle(AppColor.textSecondary)
            }

            LabeledField(label: "Password", text: $password,
                         isSecure: true, textContentType: .newPassword)

            StrengthBar(strength: PasswordRules.strength(password))

            if PasswordRules.isValid(password) {
                Text("Strong password — well done!")
                    .font(.headline)
                    .foregroundStyle(AppColor.success)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                RuleRow(text: "At least 8 characters", met: password.count >= 8)
                RuleRow(text: "Contains a number", met: PasswordRules.hasNumber(password))
                RuleRow(text: "Contains a capital letter", met: PasswordRules.hasCapital(password))
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColor.textSecondary.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(.horizontal, Spacing.lg)
    }
}

private struct RuleRow: View {
    let text: String
    let met: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? AppColor.success : AppColor.textSecondary.opacity(0.4))
            Text(text)
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text). \(met ? "Met" : "Not yet met").")
    }
}

private struct StrengthBar: View {
    let strength: Int   // 0...3

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index < strength ? AppColor.success : AppColor.textSecondary.opacity(0.2))
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Step 3: companion

private struct CompanionStep: View {
    @Binding var selection: Companion?

    private let columns = [GridItem(.flexible(), spacing: Spacing.md),
                           GridItem(.flexible(), spacing: Spacing.md)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Choose your companion")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("They'll grow as you save memories.")
                    .font(.title3)
                    .foregroundStyle(AppColor.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(Companion.allCases) { companion in
                    CompanionCard(companion: companion,
                                  isSelected: selection == companion) {
                        selection = companion
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

private struct CompanionCard: View {
    let companion: Companion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: Spacing.sm) {
                    Text(companion.emoji)
                        .font(.system(size: 64))
                    Text(companion.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColor.purple)
                        .padding(Spacing.sm)
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? AppColor.purple : .clear, lineWidth: 2.5)
            )
        }
        .accessibilityLabel(companion.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Step 4: success

private struct AccountCreatedStep: View {
    let firstName: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColor.successSoft)
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(AppColor.success)
            }
            Text("Your account is ready!")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textPrimary)
            Text("Welcome, \(firstName.isEmpty ? "friend" : firstName). Next, let's choose your companion.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Password rules

enum PasswordRules {
    static func hasNumber(_ s: String) -> Bool { s.contains { $0.isNumber } }
    static func hasCapital(_ s: String) -> Bool { s.contains { $0.isUppercase } }
    static func isValid(_ s: String) -> Bool {
        s.count >= 8 && hasNumber(s) && hasCapital(s)
    }
    /// 0 = none, up to 3 = all rules satisfied.
    static func strength(_ s: String) -> Int {
        var score = 0
        if s.count >= 8 { score += 1 }
        if hasNumber(s) { score += 1 }
        if hasCapital(s) { score += 1 }
        return score
    }
}

#Preview {
    CreateAccountView(onComplete: { _ in }, onCancel: {})
}
