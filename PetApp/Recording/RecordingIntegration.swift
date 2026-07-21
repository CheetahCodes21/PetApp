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
//  This file is the seam between capture (KAN-19) and the save flow (KAN-20):
//  `RecordingView` only captures and hands back a `RecordingDraft`; here we
//  present the completion / save sheet (`SaveMemoryView`) and surface the
//  resulting `SavedMemory`. Capture code is untouched by this layer.
//

import SwiftUI

extension View {

    /// Presents the recording flow, then the completion sheet, as full-screen
    /// covers. This is the entry point the main screen's Record button uses.
    ///
    /// - Parameters:
    ///   - isPresented: Toggled true by the Record button; reset automatically.
    ///   - question: The journalling question being answered, shown for context.
    ///   - onSaved: Called with the saved memory once the user completes the save
    ///     sheet (title, transcript, photo, date). Use it to route to the memory
    ///     screen (Dev 4).
    func memoryRecorder(isPresented: Binding<Bool>,
                        question: String? = nil,
                        onSaved: @escaping (SavedMemory) -> Void = { _ in }) -> some View {
        modifier(MemoryRecorderModifier(isPresented: isPresented,
                                        question: question,
                                        onSaved: onSaved))
    }

    /// Offers back a recording that was interrupted or lost to termination
    /// (KAN-35), then routes Continue / Save through the same save sheet. Add
    /// this once, near the app root or on the main screen.
    func recordingRecovery(onSaved: @escaping (SavedMemory) -> Void = { _ in }) -> some View {
        modifier(RecordingRecoveryModifier(onSaved: onSaved))
    }
}

/// Presents the recording cover, then the save sheet once the user keeps a
/// recording. The two covers are sequenced (present the save sheet only after
/// the recording cover has fully dismissed) so the presentations don't collide.
private struct MemoryRecorderModifier: ViewModifier {
    @Binding var isPresented: Bool
    let question: String?
    let onSaved: (SavedMemory) -> Void

    @State private var saving: RecordingDraft?
    @State private var pendingSave: RecordingDraft?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, onDismiss: {
                if let pendingSave {
                    saving = pendingSave
                    self.pendingSave = nil
                }
            }) {
                RecordingView(
                    question: question,
                    onFinish: { draft in
                        pendingSave = draft
                        isPresented = false
                    },
                    onCancel: { isPresented = false }
                )
            }
            .fullScreenCover(item: $saving) { draft in
                SaveMemoryView(
                    draft: draft,
                    onSave: { memory in
                        saving = nil
                        onSaved(memory)
                    },
                    onCancel: { saving = nil }
                )
            }
    }
}

/// Drives the crash-recovery prompt, the resume-recording cover, and the save
/// sheet. Each presentation is promoted only after the previous one dismisses.
private struct RecordingRecoveryModifier: ViewModifier {
    let onSaved: (SavedMemory) -> Void

    @State private var recoverable: RecordingDraft?
    @State private var resuming: RecordingDraft?
    @State private var saving: RecordingDraft?
    @State private var pendingResume: RecordingDraft?
    @State private var pendingSave: RecordingDraft?

    func body(content: Content) -> some View {
        content
            .task {
                if recoverable == nil {
                    recoverable = DraftStore.shared.recoverableDrafts().first
                }
            }
            .sheet(item: $recoverable, onDismiss: {
                if let pendingResume {
                    resuming = pendingResume
                    self.pendingResume = nil
                } else if let pendingSave {
                    saving = pendingSave
                    self.pendingSave = nil
                }
            }) { draft in
                RecoveryPromptView(
                    draft: draft,
                    onContinue: { toContinue in
                        pendingResume = toContinue
                        recoverable = nil
                    },
                    onSave: { toSave in
                        pendingSave = toSave
                        recoverable = nil
                    },
                    onDelete: { toDelete in
                        DraftStore.shared.delete(toDelete)
                        recoverable = nil
                    }
                )
            }
            .fullScreenCover(item: $resuming, onDismiss: {
                if let pendingSave {
                    saving = pendingSave
                    self.pendingSave = nil
                }
            }) { draft in
                RecordingView(
                    question: draft.questionText,
                    resuming: draft,
                    onFinish: { finished in
                        pendingSave = finished
                        resuming = nil
                    },
                    onCancel: { resuming = nil }
                )
            }
            .fullScreenCover(item: $saving) { draft in
                SaveMemoryView(
                    draft: draft,
                    onSave: { memory in
                        saving = nil
                        onSaved(memory)
                    },
                    onCancel: { saving = nil }
                )
            }
    }
}
