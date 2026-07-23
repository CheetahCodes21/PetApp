//
//  LoadingOverlay.swift
//  PetApp
//
//  Frosted-glass loading overlay that softly blurs the screen behind it and
//  plays the bundled loading Lottie animation while an async task is in
//  progress. Styled to match the app's lavender theme.
//

import SwiftUI

struct LoadingOverlay: View {
    var message: String = "Just a moment…"

    @State private var pulse = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Frosted blur + a gentle lavender wash over whatever is behind.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            AppColor.thistle.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                ZStack {
                    // Soft breathing glow behind the animation.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppColor.ninja.opacity(0.45), .clear],
                                center: .center, startRadius: 4, endRadius: 130)
                        )
                        .frame(width: 240, height: 240)
                        .blur(radius: 24)
                        .scaleEffect(pulse ? 1.1 : 0.85)

                    LottieView(name: "LoadingPage")
                        .frame(width: 260, height: 130)
                }

                Text(LocalizedStringKey(message))
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .opacity(pulse ? 1.0 : 0.6)
                    .accessibilityHidden(true)
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
                            colors: [AppColor.ninja.opacity(0.55),
                                     AppColor.blackberry.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
            .shadow(color: AppColor.blackberry.opacity(0.22), radius: 30, y: 14)
            .padding(.horizontal, Spacing.xl)
            .scaleEffect(appeared ? 1.0 : 0.92)
            .opacity(appeared ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(message)))
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
