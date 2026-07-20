//
//  RecordingIntegration.swift
//  PetApp
//
//  The public, one-line surface other screens use to add recording, so the
//  recording UI stays owned by the audio workstream (Dev 3) while the main
//  screen stays owned by Dev 2. The main screen's Record button drives
//  `.memoryRecorder`, and the app (or main screen) adds `.recordingRecovery`
//  once so an interrupted recording is offered back on next launch.
//
//  Scope (KAN-19 / KAN-35): this layer captures audio and hands back a finished
//  `RecordingDraft`. Turning a draft into a saved memory (title, transcript,
//  photo) is the save-memory flow (KAN-20), which extends this file to present
//  the completion sheet. Until then, callers receive the raw draft.
//

import SwiftUI

extension View {

    /// Presents the recording flow as a full-screen cover when `isPresented`
    /// becomes true. This is the entry point the main screen's Record button
    /// uses — one modifier, no knowledge of the recorder needed.
    ///
    /// - Parameters:
    ///   - isPresented: Toggled true by the Record button; reset automatically.
    ///   - question: The journalling question being answered, shown for context.
    ///   - onFinish: Called with the finished `RecordingDraft` when the user
    ///     keeps the recording. KAN-20 replaces this with the save sheet.
    func memoryRecorder(isPresented: Binding<Bool>,
                        question: String? = nil,
                        onFinish: @escaping (RecordingDraft) -> Void = { _ in }) -> some View {
        fullScreenCover(isPresented: isPresented) {
            RecordingView(
                question: question,
                onFinish: { draft in
                    isPresented.wrappedValue = false
                    onFinish(draft)
                },
                onCancel: { isPresented.wrappedValue = false }
            )
        }
    }

    /// Offers back a recording that was interrupted or lost to termination
    /// (KAN-35). Add this once, near the app root or on the main screen; it
    /// checks for a recoverable draft on appear and presents the recovery
    /// prompt, wiring up Continue / Keep / Delete.
    ///
    /// - Parameter onKeep: Called with the recovered draft when the user keeps
    ///   it. KAN-20 routes this into the save sheet.
    func recordingRecovery(onKeep: @escaping (RecordingDraft) -> Void = { _ in }) -> some View {
        modifier(RecordingRecoveryModifier(onKeep: onKeep))
    }
}

/// Drives the crash-recovery prompt and the resume-recording cover.
private struct RecordingRecoveryModifier: ViewModifier {
    let onKeep: (RecordingDraft) -> Void

    @State private var recoverable: RecordingDraft?
    @State private var resuming: RecordingDraft?
    @State private var pendingResume: RecordingDraft?
    @State private var pendingKeep: RecordingDraft?

    func body(content: Content) -> some View {
        content
            .task {
                if recoverable == nil {
                    recoverable = DraftStore.shared.recoverableDrafts().first
                }
            }
            .sheet(item: $recoverable, onDismiss: {
                // Act on the user's choice only after the recovery sheet has
                // fully dismissed, so presentations don't collide.
                if let pendingResume {
                    resuming = pendingResume
                    self.pendingResume = nil
                } else if let pendingKeep {
                    onKeep(pendingKeep)
                    self.pendingKeep = nil
                }
            }) { draft in
                RecoveryPromptView(
                    draft: draft,
                    onContinue: { toContinue in
                        pendingResume = toContinue
                        recoverable = nil
                    },
                    onSave: { toKeep in
                        pendingKeep = toKeep
                        recoverable = nil
                    },
                    onDelete: { toDelete in
                        DraftStore.shared.delete(toDelete)
                        recoverable = nil
                    }
                )
            }
            .fullScreenCover(item: $resuming) { draft in
                RecordingView(
                    question: draft.questionText,
                    resuming: draft,
                    onFinish: { finished in
                        resuming = nil
                        onKeep(finished)
                    },
                    onCancel: { resuming = nil }
                )
            }
    }
}
