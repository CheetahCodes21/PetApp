//
//  DailyQuestionView.swift
//  PetApp
//
//  The gentle pre-record "conversation" shown when the user taps Record. It
//  keeps the home screen uncluttered by moving the yes/no branching here:
//
//    * Today's anchor (a light yes/no opener) is shown first.
//    * "Yes" → its specific follow-up becomes the question to answer.
//    * "Not today" → a reflection prompt is offered instead (no second layer).
//
//  Whatever the user lands on resolves to a single question string handed back
//  via `onRecord`, so the recording flow is unchanged.
//
//  Read-aloud: a speaker button reads the current question at any time. It is
//  read automatically on appear / after a choice ONLY when the text-to-voice
//  setting is on (off by default) — reusing `SpeechService` and the user's
//  saved voice speed and language.
//

import SwiftUI

struct DailyQuestionView: View {
    /// Today's opener (anchor + its yes follow-up).
    let prompt: DailyPrompt
    /// Called with the resolved question when the user is ready to record.
    var onRecord: (String) -> Void
    /// Called when the user backs out without recording.
    var onCancel: () -> Void

    @EnvironmentObject private var settings: AppSettings

    /// The resolved question once the opener is answered; nil on the yes/no step.
    @State private var resolved: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    Spacer(minLength: Spacing.md)
                    questionCard(currentQuestion)
                    Spacer(minLength: Spacing.md)
                    actions
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("Today's question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        stopSpeaking()
                        onCancel()
                    }
                    .font(.title3.weight(.medium))
                }
            }
            .onAppear { autoReadIfEnabled() }
            .onDisappear { stopSpeaking() }
        }
    }

    /// The question currently on screen: the opener, or the resolved follow-up /
    /// reflection once the user has answered.
    private var currentQuestion: String { resolved ?? prompt.anchor }

    // MARK: - Question card + read aloud

    private func questionCard(_ text: String) -> some View {
        VStack(spacing: Spacing.md) {
            Text(LocalizedStringKey(text))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity)

            Button {
                readAloud(text)
            } label: {
                Label("Read aloud", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                    .foregroundStyle(AppColor.ninja)
            }
            .accessibilityLabel("Read the question aloud")
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppColor.textSecondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if resolved == nil {
            VStack(spacing: Spacing.sm) {
                Button("Yes") { answer(yes: true) }
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
                Button("Not today") { answer(yes: false) }
                    .buttonStyle(OutlinedButtonStyle())
            }
        } else {
            VStack(spacing: Spacing.sm) {
                Button {
                    stopSpeaking()
                    onRecord(currentQuestion)
                } label: {
                    Label("Record my answer", systemImage: "mic.fill")
                }
                .buttonStyle(FilledButtonStyle(background: AppColor.blackberry))

                Button("Ask me something else") { reset() }
                    .buttonStyle(OutlinedButtonStyle())
            }
        }
    }

    // MARK: - Branching

    private func answer(yes: Bool) {
        let next = yes
            ? prompt.followUpYes
            : (DailyPrompts.reflections.randomElement() ?? prompt.followUpYes)
        resolved = next
        autoReadIfEnabled(next)
    }

    private func reset() {
        stopSpeaking()
        resolved = nil
        autoReadIfEnabled(prompt.anchor)
    }

    // MARK: - Read aloud

    /// Speaks the given question only when the user has turned text-to-voice on.
    private func autoReadIfEnabled(_ text: String? = nil) {
        guard settings.textToVoice else { return }
        readAloud(text ?? currentQuestion)
    }

    private func readAloud(_ text: String) {
        // Speak the localized wording where a translation exists; untranslated
        // keys resolve back to the English text.
        let spoken = String(localized: String.LocalizationValue(text))
        SpeechService.shared.speak(spoken,
                                   speed: settings.voiceSpeed,
                                   languageCode: settings.language.rawValue)
    }

    private func stopSpeaking() {
        SpeechService.shared.stop()
    }
}

#Preview {
    DailyQuestionView(prompt: DailyPrompts.anchors[0],
                      onRecord: { _ in },
                      onCancel: {})
        .environmentObject(AppSettings())
}
