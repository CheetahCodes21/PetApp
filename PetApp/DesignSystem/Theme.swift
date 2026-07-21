//
//  Theme.swift
//  PetApp
//
//  Central design system: colors, spacing, and reusable styles.
//  Tuned for warmth and readability for an older-adult audience.
//

import SwiftUI

// MARK: - Color palette

extension Color {
    /// Builds a Color from a hex string like "#RRGGBB" or "RRGGBB".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

enum AppColor {
    // Palette sourced from Assets.xcassets → "App theme colours" so the app's
    // look is driven by the project's named theme colours.

    /// Soft lavender ("Thistle") used on the login / sign-in screens.
    static let lavender = Color("Thistle")
    /// Near-white ("Snow") used on the create-account / settings / home screens.
    static let surface = Color("Snow")
    /// Deep plum ("BlackberryCream") for the primary call-to-action.
    static let plum = Color("BlackberryCream")
    /// Muted purple ("NinjaPrincess") for primary buttons and accents.
    static let purple = Color("NinjaPrincess")
    /// Heading tint (also "NinjaPrincess").
    static let heading = Color("NinjaPrincess")

    static let textPrimary = Color(hex: "#221B2B")
    static let textSecondary = Color(hex: "#6E6A78")
    static let fieldBorder = Color(hex: "#3E2A4E")
    static let success = Color(hex: "#4E9E5F")
    static let successSoft = Color(hex: "#DCEEDF")
}

// MARK: - Spacing

enum Spacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Button styles

/// Large, high-contrast filled button. Generous height for easy tapping.
struct FilledButtonStyle: ButtonStyle {
    var background: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, Spacing.lg)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined button used for social sign-in options.
struct OutlinedButtonStyle: ButtonStyle {
    var border: Color = AppColor.fieldBorder

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.medium))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(border.opacity(0.5), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
