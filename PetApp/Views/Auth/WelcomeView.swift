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
            AppColor.surface.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Spacer()

                Text("🐤")
                    .font(.system(size: 96))
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.sm) {
                    Text("Memory Companion")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColor.heading)
                    Text("Keep your memories close,\none day at a time.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColor.textPrimary)
                }

                Spacer()

                VStack(spacing: Spacing.md) {
                    Button("Create an account", action: onCreateAccount)
                        .buttonStyle(FilledButtonStyle(background: AppColor.plum))

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
