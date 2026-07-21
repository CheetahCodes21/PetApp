//
//  WelcomeView.swift
//  PetApp
//
//  Entry screen: branch to account creation (new users) or login (existing).
//

import SwiftUI

struct WelcomeView: View {
    let onCreateAccount: () -> Void
    let onLogIn: () -> Void

    var body: some View {
        ZStack {
            AppColor.snow.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Spacer()

                Text("🐤")
                    .font(.system(size: 96))
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.sm) {
                    Text("MemoMe")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColor.heading)
                    Text("A companion for your everyday memories.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColor.textPrimary)
                }

                Spacer()

                VStack(spacing: Spacing.md) {
                    Button("Create an account", action: onCreateAccount)
                        .buttonStyle(FilledButtonStyle(background: AppColor.blackberry))

                    Button("I already have an account", action: onLogIn)
                        .buttonStyle(OutlinedButtonStyle())
                }
                .padding(.horizontal, Spacing.lg)

                LegalFooter()
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.lg)
            }
        }
    }
}

#Preview {
    WelcomeView(onCreateAccount: {}, onLogIn: {})
}
