//
//  AuthComponents.swift
//  PetApp
//
//  Small reusable views shared across the auth & onboarding screens.
//

import SwiftUI

// MARK: - Legal footer

struct LegalFooter: View {
    var body: some View {
        // Localized via the String Catalog; markdown bold keeps Terms /
        // Privacy Policy emphasised.
        Text("By using this App, you agree to the **Terms** and **Privacy Policy**.")
            .font(.subheadline)
            .foregroundStyle(AppColor.textSecondary)
            .tint(AppColor.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Social sign-in button

enum SocialProvider: String, Identifiable {
    case apple
    var id: String { rawValue }
}

struct SocialButton: View {
    let provider: SocialProvider
    let action: () -> Void

    private var title: String {
        switch provider {
        case .apple: return "Continue with Apple"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                icon
                Text(title)
            }
        }
        .buttonStyle(OutlinedButtonStyle())
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var icon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.title3)
                .foregroundStyle(.black)
        }
    }
}

// MARK: - Labeled text field

struct LabeledField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var textContentType: UITextContentType?

    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !label.isEmpty {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
            }
            HStack {
                Group {
                    if isSecure && !reveal {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.title3)
                .keyboardType(keyboard)
                .textContentType(textContentType)
                .autocorrectionDisabled(isSecure || keyboard == .emailAddress)
                .textInputAutocapitalization(isSecure || keyboard == .emailAddress ? .never : .sentences)

                if isSecure {
                    Button {
                        reveal.toggle()
                    } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye")
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .accessibilityLabel(reveal ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColor.fieldBorder.opacity(0.6), lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Step progress dots

struct StepProgress: View {
    let total: Int
    let current: Int   // 1-based

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < current ? AppColor.ninja : AppColor.ninja.opacity(0.2))
                    .frame(width: index < current ? 26 : 22, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}
