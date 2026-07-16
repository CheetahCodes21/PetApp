//
//  LoginView.swift
//  PetApp
//
//  "Log into account" landing for returning users (mockup 1).
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    let onContinueWithEmail: () -> Void

    var body: some View {
        ZStack {
            AppColor.lavender.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Log into account")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColor.heading)
                    .padding(.top, Spacing.sm)

                VStack(spacing: Spacing.xs) {
                    Text("Welcome back!")
                    Text("Let's continue")
                }
                .font(.title3)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, Spacing.xl)

                Spacer(minLength: Spacing.xl)

                Button(action: onContinueWithEmail) {
                    Text("Continue with email or Phone No.")
                }
                .buttonStyle(FilledButtonStyle(background: AppColor.plum))
                .padding(.horizontal, Spacing.lg)

                Text("or")
                    .font(.headline)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.vertical, Spacing.xl)

                VStack(spacing: Spacing.md) {
                    SocialButton(provider: .apple) { auth.continueWith(provider: .apple) }
                    SocialButton(provider: .facebook) { auth.continueWith(provider: .facebook) }
                    SocialButton(provider: .google) { auth.continueWith(provider: .google) }
                }
                .padding(.horizontal, Spacing.lg)

                Spacer(minLength: Spacing.xl)

                LegalFooter()
                    .padding(.bottom, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(AppColor.lavender, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        LoginView(onContinueWithEmail: {})
            .environmentObject(AuthViewModel())
    }
}
