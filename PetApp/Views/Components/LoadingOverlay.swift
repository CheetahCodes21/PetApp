//
//  LoadingOverlay.swift
//  PetApp
//
//  Frosted-glass loading overlay that blurs the screen behind it and plays
//  the bundled portal Lottie animation while an async task is in progress.
//

import SwiftUI

struct LoadingOverlay: View {
    var message: String = "Just a moment…"

    @State private var pulse = false

    var body: some View {
        ZStack {
            // Frosted blur of whatever is behind the overlay.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                ZStack {
                    // Soft glowing aura behind the animation.
                    Circle()
                        .fill(AppColor.purple.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .blur(radius: 45)
                        .scaleEffect(pulse ? 1.12 : 0.9)

                    LottieView(name: "LoadingPortal")
                        .frame(width: 240, height: 120)
                }

                Text(message)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .opacity(pulse ? 1.0 : 0.55)
            }
            .padding(.vertical, Spacing.xl)
            .padding(.horizontal, Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [AppColor.purple.opacity(0.55), AppColor.purple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
            .shadow(color: AppColor.purple.opacity(0.28), radius: 28, y: 12)
            .padding(.horizontal, Spacing.xl)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

extension View {
    /// Shows a frosted, glowing loading overlay when `isActive` is true.
    func loadingOverlay(_ isActive: Bool, message: String = "Just a moment…") -> some View {
        overlay {
            if isActive {
                LoadingOverlay(message: message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }
}
