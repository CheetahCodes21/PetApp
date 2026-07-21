//
//  LoadingOverlay.swift
//  PetApp
//
//  Full-screen loading overlay that plays the bundled portal Lottie animation
//  while an async task (sign in / sign up / Apple) is in progress.
//

import SwiftUI

struct LoadingOverlay: View {
    var message: String = "Just a moment…"

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                LottieView(name: "LoadingPortal")
                    .frame(width: 220, height: 100)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(Spacing.xl)
            .background(AppColor.surface,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

extension View {
    /// Shows a loading overlay with the portal animation when `isActive` is true.
    func loadingOverlay(_ isActive: Bool, message: String = "Just a moment…") -> some View {
        overlay {
            if isActive {
                LoadingOverlay(message: message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}
