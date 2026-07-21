//
//  RecoveryPromptView.swift
//  PetApp
//
//  Shown on next launch when a recording was interrupted or the app closed
//  mid-recording (KAN-35 "Never lose a recording", US-037 AC4). States that the
//  recording was kept, shows its date and length, and offers Listen, Continue,
//  Save, and Delete. The prompt persists until the user acts on it.
//

import SwiftUI
import AVFoundation

struct RecoveryPromptView: View {
    let draft: RecordingDraft
    /// Resume recording, appending to this draft.
    var onContinue: (RecordingDraft) -> Void
    /// Keep it as a memory (hands off to the save flow later).
    var onSave: (RecordingDraft) -> Void
    /// Discard it for good.
    var onDelete: (RecordingDraft) -> Void

    @State private var player: AVQueuePlayer?
    @State private var isPlaying = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text("We kept your recording")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.textPrimary)

                Text("You started a recording that didn't get saved. It's safe — here it is.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.textSecondary)

                detailsCard

                Spacer(minLength: Spacing.md)

                VStack(spacing: Spacing.sm) {
                    Button(isPlaying ? "Stop" : "Listen") { togglePlayback() }
                        .buttonStyle(OutlinedButtonStyle())
                    Button("Continue recording") { stopPlayback(); onContinue(draft) }
                        .buttonStyle(FilledButtonStyle(background: AppColor.purple))
                    Button("Save as a memory") { stopPlayback(); onSave(draft) }
                        .buttonStyle(FilledButtonStyle(background: AppColor.success))
                    Button("Delete", role: .destructive) { showDeleteConfirm = true }
                        .buttonStyle(OutlinedButtonStyle())
                }
            }
            .padding(Spacing.lg)
        }
        .interactiveDismissDisabled(true)
        .alert("Delete this recording?", isPresented: $showDeleteConfirm) {
            Button("Keep it", role: .cancel) {}
            Button("Delete", role: .destructive) { stopPlayback(); onDelete(draft) }
        } message: {
            Text("This removes the recording for good. This can't be undone.")
        }
        .onDisappear { stopPlayback() }
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(spacing: Spacing.xs) {
            row("Recorded", value: draft.createdAt.formatted(date: .abbreviated, time: .shortened))
            row("Length", value: RecordingView.timeString(draft.duration))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.lavender.opacity(0.4))
        )
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.title3)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        let store = DraftStore.shared
        let items = draft.segmentFileNames
            .map { store.segmentURL(named: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { AVPlayerItem(url: $0) }
        guard !items.isEmpty else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let queue = AVQueuePlayer(items: items)
        player = queue
        isPlaying = true
        queue.play()
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

#Preview {
    RecoveryPromptView(
        draft: {
            var draft = RecordingDraft()
            draft.duration = 84
            draft.segmentFileNames = ["sample.m4a"]
            return draft
        }(),
        onContinue: { _ in },
        onSave: { _ in },
        onDelete: { _ in }
    )
}
