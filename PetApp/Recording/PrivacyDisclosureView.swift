//
//  PrivacyDisclosureView.swift
//  PetApp
//
//  Plain-language explanation of how voice recordings are handled (KAN-38,
//  US-034). Shown once before the first transcription, and reachable any time
//  from Settings (Dev 5 links here — see README).
//

import SwiftUI

struct PrivacyDisclosureView: View {
    /// Called when the user acknowledges. nil when shown purely for reference
    /// (e.g. opened from Settings), which hides the acknowledge button.
    var onAcknowledge: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Your recordings stay private")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)

                    point("On your device",
                          "Your voice is turned into text right here on your iPhone. The audio is not sent to a server to do this.")
                    point("Kept safe",
                          "Your recordings and their words are stored encrypted on your device.")
                    point("Yours to keep or remove",
                          "You can read, edit, or delete any memory at any time. Nothing is shared unless you choose to share it.")

                    if onAcknowledge != nil {
                        Button("Got it") {
                            onAcknowledge?()
                            dismiss()
                        }
                        .buttonStyle(FilledButtonStyle(background: AppColor.purple))
                        .padding(.top, Spacing.md)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(AppColor.surface.ignoresSafeArea())
            .toolbar {
                if onAcknowledge == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(onAcknowledge != nil)
    }

    private func point(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            Text(body)
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

#Preview {
    PrivacyDisclosureView(onAcknowledge: {})
}
