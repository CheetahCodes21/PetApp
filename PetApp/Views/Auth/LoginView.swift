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
    @State private var working = false

    var body: some View {
        ZStack {
            AppColor.snow
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                VStack(spacing: Spacing.md) {
                    Text("Log into account")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColor.heading)

                    VStack(spacing: 4) {
                        Text("Welcome back!")
                        Text("Let's continue your journey")
                    }
                    .font(.title3)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                }
                .padding(.top, 60)


                Spacer()


                // Login options
                VStack(spacing: 24) {

                    // Apple Sign In (Primary)
                    AppleSignInButton { result in
                        handleApple(result)
                    }
                    .frame(height: 54)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                    )


                    // Divider
                    HStack {
                        Rectangle()
                            .fill(
                                AppColor.textSecondary.opacity(0.25)
                            )
                            .frame(height: 1)

                        Text("or")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColor.textSecondary)

                        Rectangle()
                            .fill(
                                AppColor.textSecondary.opacity(0.25)
                            )
                            .frame(height: 1)
                    }


                    // Email Sign In (Secondary)
                    Button(action: onContinueWithEmail) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Continue with email")
                        }
                    }
                    .buttonStyle(
                        FilledButtonStyle(background: AppColor.blackberry)
                    )
                    .frame(height: 54)
                }
                .padding(.horizontal, 32)


                Spacer()


                // Footer
                LegalFooter()
                    .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(AppColor.thistle, for: .navigationBar)
        .loadingOverlay(
            working,
            message: "Signing you in…"
        )


        // Not available alert
        .alert(
            "Not available yet",
            isPresented: Binding(
                get: {
                    unavailableProvider != nil
                },
                set: {
                    if !$0 {
                        unavailableProvider = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "\(unavailableProvider ?? "This") sign-in isn't set up yet. Please use Apple or email for now."
            )
        }


        // Apple error alert
        .alert(
            "Sign-in problem",
            isPresented: Binding(
                get: {
                    appleError != nil
                },
                set: {
                    if !$0 {
                        appleError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appleError ?? "")
        }
    }


    private func handleApple(
        _ result: Result<AppleCredential, Error>
    ) {

        switch result {

        case .success(let credential):

            working = true

            Task {
                do {

                    try await auth.signInWithApple(
                        credential
                    )

                    await MainActor.run {
                        working = false
                        auth.enterApp()
                    }

                } catch {

                    await MainActor.run {
                        working = false

                        appleError =
                        (error as? LocalizedError)?
                            .errorDescription
                        ?? "We couldn't complete Apple sign-in. Please try again."
                    }
                }
            }


        case .failure:
            // User cancelled Apple sign-in
            break
        }
    }
}


#Preview {
    NavigationStack {
        LoginView(
            onContinueWithEmail: {}
        )
        .environmentObject(
            AuthViewModel()
        )
    }
}
