//
//  SignInView.swift
//  PetApp
//
//  Email / phone + password entry for returning users (mockup 2).
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ZStack {
            AppColor.lavender.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Log into account")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColor.heading)
                    .padding(.top, Spacing.sm)

                Spacer(minLength: Spacing.xl)

                Text("Sign In")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(AppColor.plum)
                    .padding(.bottom, Spacing.lg)

                VStack(spacing: Spacing.md) {
                    LabeledField(
                        label: "",
                        placeholder: "Email or Phone number",
                        text: $auth.loginIdentifier,
                        keyboard: .emailAddress,
                        textContentType: .username
                    )

                    LabeledField(
                        label: "",
                        placeholder: "Password",
                        text: $auth.loginPassword,
                        isSecure: true,
                        textContentType: .password
                    )
                }
                .padding(.horizontal, Spacing.lg)

                Button(action: auth.signIn) {
                    if auth.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Next")
                    }
                }
                .buttonStyle(FilledButtonStyle(background: AppColor.plum))
                .frame(width: 200)
                .padding(.top, Spacing.lg)
                .disabled(!auth.canSubmitSignIn || auth.isWorking)
                .opacity(auth.canSubmitSignIn ? 1 : 0.5)

                Button("Forgot password?") { }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.top, Spacing.md)

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.top, Spacing.sm)
                }

                Spacer()

                LegalFooter()
                    .padding(.bottom, Spacing.lg)
            }
        }
        .toolbarBackground(AppColor.lavender, for: .navigationBar)
        .loadingOverlay(auth.isWorking, message: "Signing you in…")
    }
}

#Preview {
    NavigationStack {
        SignInView().environmentObject(AuthViewModel())
    }
}
