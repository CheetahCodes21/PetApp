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

    @State private var unavailableProvider: String?
    @State private var appleError: String?

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
                    AppleSignInButton { result in handleApple(result) }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    SocialButton(provider: .facebook) { unavailableProvider = "Facebook" }
                    SocialButton(provider: .google) { unavailableProvider = "Google" }
                }
                .padding(.horizontal, Spacing.lg)

                Spacer(minLength: Spacing.xl)

                LegalFooter()
                    .padding(.bottom, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(AppColor.lavender, for: .navigationBar)
        .alert("Not available yet",
               isPresented: Binding(get: { unavailableProvider != nil },
                                    set: { if !$0 { unavailableProvider = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(unavailableProvider ?? "This") sign-in isn't set up yet. Please use Apple or email for now.")
        }
        .alert("Sign-in problem",
               isPresented: Binding(get: { appleError != nil },
                                    set: { if !$0 { appleError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appleError ?? "")
        }
    }

    private func handleApple(_ result: Result<AppleCredential, Error>) {
        switch result {
        case .success(let credential):
            Task {
                do {
                    try await auth.signInWithApple(credential)
                    auth.enterApp()
                } catch {
                    appleError = (error as? LocalizedError)?.errorDescription
                        ?? "We couldn't complete Apple sign-in. Please try again."
                }
            }
        case .failure:
            // User cancelled or the request failed; stay on the screen quietly.
            break
        }
    }
}

#Preview {
    NavigationStack {
        LoginView(onContinueWithEmail: {})
            .environmentObject(AuthViewModel())
    }
}
