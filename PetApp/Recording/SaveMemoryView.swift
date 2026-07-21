//
//  SaveMemoryView.swift
//  PetApp
//
//  The completion sheet (KAN-20 "Complete and save a memory", US-016): title,
//  audio playback with scrubbing, an editable transcript that fills in when
//  speech-to-text finishes, a date, and Save / Cancel. Assembles the draft's
//  segments into one file, transcribes it on-device, and produces a SavedMemory.
//

import SwiftUI
import AVFoundation
import Combine
import UIKit

// MARK: - Model

@MainActor
final class SaveMemoryModel: ObservableObject {
    let draft: RecordingDraft
    private let memoryID = UUID().uuidString

    @Published var title = ""
    @Published var date: Date
    @Published var transcript = ""
    @Published private(set) var transcriptState: TranscriptState = .none
    @Published private(set) var isPreparing = true
    @Published var errorMessage: String?

    @Published private(set) var isPlaying = false
    @Published var progress: Double = 0
    /// Optional attached photo (KAN-21).
    @Published var photo: UIImage?

    let duration: TimeInterval
    private(set) var assembledURL: URL?
    private var player: AVPlayer?
    private var timeObserver: Any?

    init(draft: RecordingDraft) {
        self.draft = draft
        self.date = draft.createdAt
        self.duration = draft.duration
    }

    /// A title suggestion prefilled when the user leaves the field empty.
    var suggestedTitle: String {
        if let question = draft.questionText, !question.isEmpty { return question }
        return "Memory from " + draft.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: Prepare (assemble + transcribe)

    /// Assembles the audio and sets up playback. Transcription is started
    /// separately so it can wait for the privacy disclosure (KAN-38).
    func prepareAudio() async {
        isPreparing = true
        let segments = draft.segmentFileNames.map { DraftStore.shared.segmentURL(named: $0) }
        let output = MemoryStore.shared.newAudioURL(for: memoryID)
        do {
            try await AudioAssembler.assemble(segmentURLs: segments, to: output)
            assembledURL = output
        } catch {
            // Assembly failed: keep the recording safe by playing the raw first
            // segment; the memory still saves.
            assembledURL = segments.first
            errorMessage = "We had trouble joining the audio, but your recording is safe."
        }
        if let url = assembledURL { setupPlayer(url: url) }
        isPreparing = false
    }

    func startTranscription() async {
        await runTranscription()
    }

    private func runTranscription() async {
        guard let url = assembledURL else { transcriptState = .none; return }
        transcriptState = .pending
        do {
            transcript = try await TranscriptionService.transcribe(url: url)
            transcriptState = .ready
        } catch {
            transcriptState = .failed
        }
    }

    func retryTranscription() {
        Task { await runTranscription() }
    }

    // MARK: Playback

    private func setupPlayer(url: URL) {
        let player = AVPlayer(url: url)
        self.player = player
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, self.duration > 0 else { return }
                self.progress = min(1, time.seconds / self.duration)
                if time.seconds >= self.duration { self.isPlaying = false }
            }
        }
    }

    func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if progress >= 1 { seek(to: 0) }
            player.play()
            isPlaying = true
        }
    }

    func seek(to fraction: Double) {
        guard let player, duration > 0 else { return }
        player.seek(to: CMTime(seconds: fraction * duration, preferredTimescale: 600))
        progress = fraction
    }

    // MARK: Save / discard

    func save() -> SavedMemory {
        let trimmed = title.trimmingCharacters(in: .whitespaces)

        // Persist the photo (compressed) if one was attached.
        var photoName: String?
        if let photo, let data = photo.jpegData(compressionQuality: 0.8) {
            let url = MemoryStore.shared.newPhotoURL(for: memoryID)
            try? data.write(to: url)
            photoName = url.lastPathComponent
        }

        let memory = SavedMemory(
            id: memoryID,
            title: trimmed.isEmpty ? suggestedTitle : trimmed,
            createdAt: date,
            audioFileName: assembledURL?.lastPathComponent ?? "\(memoryID).m4a",
            duration: duration,
            questionText: draft.questionText,
            transcript: transcript,
            transcriptState: transcriptState,
            photoFileName: photoName
        )
        MemoryStore.shared.save(memory)
        DraftStore.shared.delete(draft)   // the assembled copy is the memory now
        teardownPlayer()

        // US-016 AC4: if the user saves while transcription is still running,
        // keep transcribing independently of this view and attach the result to
        // the stored memory when it's ready. A detached task is used so it
        // survives the sheet being dismissed on save.
        if transcriptState == .pending, let url = assembledURL {
            let id = memoryID
            Task.detached {
                do {
                    let text = try await TranscriptionService.transcribe(url: url)
                    await MemoryStore.shared.attachTranscript(memoryID: id,
                                                              transcript: text,
                                                              state: .ready)
                } catch {
                    await MemoryStore.shared.attachTranscript(memoryID: id,
                                                              transcript: "",
                                                              state: .failed)
                }
            }
        }
        return memory
    }

    func discard() {
        teardownPlayer()
        if let assembledURL { try? FileManager.default.removeItem(at: assembledURL) }
        DraftStore.shared.delete(draft)
    }

    func teardownPlayer() {
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        player = nil
        isPlaying = false
    }
}

// MARK: - View

struct SaveMemoryView: View {
    @StateObject private var model: SaveMemoryModel
    var onSave: (SavedMemory) -> Void
    var onCancel: () -> Void

    @State private var showDiscardConfirm = false
    @State private var titleMissing = false
    @FocusState private var titleFocused: Bool
    /// One-time voice-privacy acknowledgement before the first transcription.
    @AppStorage("voicePrivacyAcknowledged") private var privacyAcknowledged = false
    @State private var showPrivacy = false
    /// Drives the auto-dismissing "Saved" confirmation (US-016 AC6).
    @State private var showSavedConfirmation = false

    init(draft: RecordingDraft,
         onSave: @escaping (SavedMemory) -> Void,
         onCancel: @escaping () -> Void) {
        _model = StateObject(wrappedValue: SaveMemoryModel(draft: draft))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    titleSection
                    playbackSection
                    transcriptSection
                    PhotoAttachmentView(image: $model.photo)
                    dateSection
                }
                .padding(Spacing.lg)
            }
            .background(AppColor.surface.ignoresSafeArea())
            .navigationTitle("Save memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showDiscardConfirm = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveTapped() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                await model.prepareAudio()
                // Show the privacy note before the very first transcription.
                if privacyAcknowledged {
                    await model.startTranscription()
                } else {
                    showPrivacy = true
                }
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyDisclosureView(onAcknowledge: {
                    privacyAcknowledged = true
                    Task { await model.startTranscription() }
                })
            }
            .alert("Discard this recording?", isPresented: $showDiscardConfirm) {
                Button("Keep editing", role: .cancel) {}
                Button("Discard", role: .destructive) { model.discard(); onCancel() }
            } message: {
                Text("Your recording and its transcript will be removed. This can't be undone.")
            }
        }
        .interactiveDismissDisabled(true)
        .overlay {
            if showSavedConfirmation { SavedConfirmationToast() }
        }
    }

    // MARK: Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Title").font(.headline).foregroundStyle(AppColor.textPrimary)
            TextField("Give this memory a title", text: $model.title)
                .font(.title3)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(titleMissing ? AppColor.plum : AppColor.fieldBorder.opacity(0.4),
                                lineWidth: titleMissing ? 2 : 1)
                )
                .focused($titleFocused)
                .onChange(of: model.title) { _, _ in titleMissing = false }
            if titleMissing {
                Text("We added a title for you — keep it or type your own, then tap Save.")
                    .font(.callout)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Your recording").font(.headline).foregroundStyle(AppColor.textPrimary)
            if model.isPreparing {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Preparing your recording…")
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.sm)
            } else {
                HStack(spacing: Spacing.md) {
                    Button {
                        model.togglePlay()
                    } label: {
                        Label(model.isPlaying ? "Pause" : "Play",
                              systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(AppColor.purple))
                    }
                    Text(RecordingView.timeString(model.progress * model.duration)
                         + " / " + RecordingView.timeString(model.duration))
                        .monospacedDigit()
                        .foregroundStyle(AppColor.textSecondary)
                }
                Slider(value: Binding(get: { model.progress },
                                      set: { model.seek(to: $0) }), in: 0...1)
                    .tint(AppColor.purple)
            }
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("What you said").font(.headline).foregroundStyle(AppColor.textPrimary)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.transcript)
                    .font(.body)
                    .frame(minHeight: 140)
                    .padding(Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColor.fieldBorder.opacity(0.4), lineWidth: 1)
                    )
                if model.transcriptState == .pending {
                    HStack(spacing: Spacing.xs) {
                        ProgressView()
                        Text("Still writing this out…")
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(Spacing.md)
                }
            }
            if model.transcriptState == .failed {
                HStack {
                    Text("We couldn't write this out.")
                        .foregroundStyle(AppColor.textSecondary)
                    Button("Try again") { model.retryTranscription() }
                        .foregroundStyle(AppColor.purple)
                }
                .font(.callout)
            }
        }
    }

    private var dateSection: some View {
        DatePicker("Date", selection: $model.date, displayedComponents: .date)
            .font(.headline)
            .tint(AppColor.purple)
    }

    // MARK: Actions

    private func saveTapped() {
        if model.title.trimmingCharacters(in: .whitespaces).isEmpty {
            // Prefill a suggestion and let the user accept or edit, then Save.
            model.title = model.suggestedTitle
            titleMissing = true
            titleFocused = true
            return
        }
        let memory = model.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // US-016 AC6: show an auto-dismissing confirmation with haptic feedback,
        // then return to the host (which routes back to Home).
        withAnimation { showSavedConfirmation = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            onSave(memory)
        }
    }
}

/// Small, self-contained "Saved" confirmation shown briefly after saving
/// (US-016 AC6). Inline on purpose — not a screen. Dev 5's shared `ToastView`
/// (KAN-41) can replace this once it's available app-wide.
private struct SavedConfirmationToast: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.success)
            Text("Saved")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColor.surface)
                .shadow(radius: 12)
        )
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory saved")
    }
}
