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
 
import Foundation
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
                        languageCode: String = "en-US",
                        onSaved: @escaping (SavedMemory) -> Void = { _ in }) -> some View {
        modifier(MemoryRecorderModifier(isPresented: isPresented,
                                        question: question,
                                        languageCode: languageCode,
                                        onSaved: onSaved))
    }
 
    /// Offers back a recording that was interrupted or lost to termination
    /// (KAN-35), then routes Continue / Save through the same save sheet. Add
    /// this once, near the app root or on the main screen.
    func recordingRecovery(languageCode: String = "en-US",
                           onSaved: @escaping (SavedMemory) -> Void = { _ in }) -> some View {
        modifier(RecordingRecoveryModifier(languageCode: languageCode, onSaved: onSaved))
    }
 
    /// Presents just the recording capture screen and replaces an existing
    /// memory's audio in place, skipping `SaveMemoryView`'s title/photo/date
    /// screen entirely — that screen is for creating a *new* memory, and
    /// those fields already exist on the memory being edited. This is what
    /// Memory detail's re-record button uses.
    ///
    /// - Parameters:
    ///   - isPresented: Toggled true by the re-record button; reset automatically.
    ///   - isProcessing: True while the captured audio is being assembled and
    ///     transcribed after the recording screen closes, so the caller can
    ///     show a busy state instead of looking like the tap did nothing.
    ///   - onReplaced: Called with the new audio's file name (already moved
    ///     into `FileStorageService`'s shared container, same place the rest
    ///     of the app reads from) and, if transcription succeeded, its
    ///     transcript. Transcript is nil on failure so the caller can decide
    ///     to keep the old one rather than blanking it.
    func audioReplacement(isPresented: Binding<Bool>,
                          isProcessing: Binding<Bool> = .constant(false),
                          question: String? = nil,
                          languageCode: String = "en-US",
                          onReplaced: @escaping (_ audioFileName: String, _ transcript: String?) -> Void) -> some View {
        modifier(AudioReplacementModifier(isPresented: isPresented,
                                          isProcessing: isProcessing,
                                          question: question,
                                          languageCode: languageCode,
                                          onReplaced: onReplaced))
    }
}
 
/// Presents the recording cover, then the save sheet once the user keeps a
/// recording. The two covers are sequenced (present the save sheet only after
/// the recording cover has fully dismissed) so the presentations don't collide.
private struct MemoryRecorderModifier: ViewModifier {
    @Binding var isPresented: Bool
    let question: String?
    let languageCode: String
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
                    languageCode: languageCode,
                    onSave: { memory in
                        saving = nil
                        onSaved(memory)
                    },
                    onCancel: { saving = nil }
                )
            }
    }
}
 
/// Presents only the capture screen (`RecordingView`), then assembles and
/// transcribes the result directly once it dismisses — no `SaveMemoryView`,
/// no title/photo/date. Mirrors the assemble+transcribe steps `SaveMemoryView`
/// normally does, but hands the result straight back instead of creating a
/// new memory.
private struct AudioReplacementModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var isProcessing: Bool
    let question: String?
    let languageCode: String
    let onReplaced: (String, String?) -> Void
 
    @State private var pendingDraft: RecordingDraft?
 
    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, onDismiss: {
                if let draft = pendingDraft {
                    pendingDraft = nil
                    Task { await process(draft) }
                }
            }) {
                RecordingView(
                    question: question,
                    onFinish: { draft in
                        pendingDraft = draft
                        isPresented = false
                    },
                    onCancel: { isPresented = false }
                )
            }
    }
 
    @MainActor
    private func process(_ draft: RecordingDraft) async {
        isProcessing = true
        defer { isProcessing = false }
 
        let segments = draft.segmentFileNames.map { DraftStore.shared.segmentURL(named: $0) }
        let assembled = MemoryStore.shared.newAudioURL(for: draft.id)
        do {
            try await AudioAssembler.assemble(segmentURLs: segments, to: assembled)
        } catch {
            // Recording is still safe as a draft; nothing to replace with.
            DraftStore.shared.delete(draft)
            return
        }
 
        // Best-effort — a failed/unavailable transcription shouldn't block
        // the audio swap; the caller keeps the previous transcript instead.
        let transcript = try? await TranscriptionService.transcribe(url: assembled, languageCode: languageCode)
 
        guard let audioData = try? Data(contentsOf: assembled),
              let savedFileName = try? FileStorageService.saveAudio(data: audioData,
                                                                     fileName: assembled.lastPathComponent)
        else {
            try? FileManager.default.removeItem(at: assembled)
            DraftStore.shared.delete(draft)
            return
        }
 
        try? FileManager.default.removeItem(at: assembled)
        DraftStore.shared.delete(draft)
        onReplaced(savedFileName, transcript)
    }
}
 
/// Drives the crash-recovery prompt, the resume-recording cover, and the save
/// sheet. Each presentation is promoted only after the previous one dismisses.
private struct RecordingRecoveryModifier: ViewModifier {
    let languageCode: String
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
                    languageCode: languageCode,
                    onSave: { memory in
                        saving = nil
                        onSaved(memory)
                    },
                    onCancel: { saving = nil }
                )
            }
    }
}
