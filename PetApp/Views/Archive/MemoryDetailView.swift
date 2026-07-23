//
//  MemoryDetailView.swift
//  PetApp
//
//  View and edit a saved memory: title, date, photo, transcript, and audio
//  playback, plus favourite, delete (with confirmation), and share. Editing
//  is inline — there's no separate "edit mode" screen, matching how the
//  rest of the app (e.g. onboarding) handles editable forms.
//
//  Save/Delete are laid out in the normal scrollable content, not a
//  `.safeAreaInset` bar — the app's custom bottom tab bar (MainTabView)
//  stays pinned across all pushed navigation, and stacking a second bottom
//  inset on top of it was pushing these buttons out of view.
//
 
import SwiftUI
import SwiftData
import UIKit
import AVFoundation
import Combine
 
struct MemoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
 
    @Bindable var memory: Memory
 
    @State private var isDirty = false
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showPhotoPicker = false
    @State private var showReRecord = false
    @State private var isReplacingAudio = false
    @State private var showSavedConfirmation = false
    @StateObject private var player = MemoryAudioPlayer()
 
    // Snapshot of the last-saved values, captured once on appear, so Cancel
    // can revert in-memory edits (this is a live SwiftData object — edits
    // apply immediately, before context.save() is ever called).
    @State private var hasCapturedOriginal = false
    @State private var originalTitle = ""
    @State private var originalTranscript = ""
    @State private var originalDate = Date()
    @State private var originalPhotoFileName: String?
    @State private var originalAudioFileName = ""
 
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                photoSection
                titleField
                dateField
                transcriptField
                audioSection
                actionButtons
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle(memory.title.isEmpty ? "Memory" : memory.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Spacing.md) {
                    Button {
                        toggleFavourite()
                    } label: {
                        Image(systemName: memory.isFavourite ? "star.fill" : "star")
                            .foregroundStyle(memory.isFavourite ? AppColor.ninja : AppColor.textSecondary)
                    }
                    .accessibilityLabel(memory.isFavourite ? "Remove from favourites" : "Add to favourites")
 
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share memory")
                }
            }
        }
        .overlay(alignment: .top) {
            if showSavedConfirmation { savedBanner }
        }
        .confirmationDialog(
            "Delete this memory?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareMemoryView(memory: memory)
        }
        .sheet(isPresented: $showPhotoPicker) {
            AddPhotoSheet { image in
                attachPhoto(image)
            }
        }
        .audioReplacement(isPresented: $showReRecord, isProcessing: $isReplacingAudio,
                          question: "Record a new version of \"\(memory.title)\"") { audioFileName, transcript in
            replaceAudio(fileName: audioFileName, transcript: transcript)
        }
        .onAppear { captureOriginalIfNeeded() }
        .onDisappear {
            player.stop()
            // Leaving without pressing "Save changes" (back button, swipe-back,
            // switching tabs) should discard the edit, not keep it. Save is
            // the only action that's supposed to make edits stick.
            if isDirty { cancelEdits() }
        }
    }
 
    // MARK: - Sections
 
    @ViewBuilder
    private var photoSection: some View {
        if let photoFileName = memory.photoFileName,
           let uiImage = UIImage(contentsOfFile: FileStorageService.photoURL(for: photoFileName).path) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
 
                HStack(spacing: Spacing.xs) {
                    photoIconButton(systemName: "pencil.circle.fill", label: "Change photo") {
                        showPhotoPicker = true
                    }
                    photoIconButton(systemName: "trash.circle.fill", label: "Delete photo") {
                        removePhoto()
                    }
                }
                .padding(8)
            }
        } else {
            Button {
                showPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Add a photo")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(AppColor.ninja)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(RoundedRectangle(cornerRadius: 18).fill(AppColor.snow))
            }
        }
    }
 
    private func photoIconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 30))
                .foregroundStyle(.white, .black.opacity(0.5))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }
 
    private var titleField: some View {
        fieldContainer(label: "Title") {
            TextField("Title", text: Binding(
                get: { memory.title },
                set: { memory.title = $0; markDirty() }
            ))
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppColor.textPrimary)
        }
    }
 
    private var dateField: some View {
        fieldContainer(label: "Date") {
            // A memory can't have happened in the future — same rule as the
            // initial save (SaveMemoryView), just missing here before.
            DatePicker("", selection: Binding(
                get: { memory.date },
                set: { memory.date = $0; markDirty() }
            ), in: ...Date(), displayedComponents: .date)
            .labelsHidden()
        }
    }
 
    private var transcriptField: some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel("What you shared")
            TextEditor(text: Binding(
                get: { memory.transcript },
                set: { memory.transcript = $0; markDirty() }
            ))
            .frame(minHeight: 140)
            .padding(Spacing.sm)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.snow))
        }
    }
 
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recording")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
            HStack(spacing: Spacing.md) {
                Button {
                    player.togglePlayback(fileName: memory.audioFileName)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColor.ninja)
                }
                .accessibilityLabel(player.isPlaying ? "Pause recording" : "Play recording")
 
                ProgressView(value: player.progress)
                    .tint(AppColor.ninja)
 
                Button {
                    player.stop()
                    showReRecord = true
                } label: {
                    if isReplacingAudio {
                        ProgressView()
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppColor.ninja)
                    }
                }
                .disabled(isReplacingAudio)
                .accessibilityLabel("Re-record")
            }
            .padding(Spacing.sm)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.snow))
        }
    }
 
    /// Small pencil next to a label, to visually flag that the field below
    /// it is directly editable (there's no separate edit-mode toggle).
    private func fieldLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
            Image(systemName: "pencil")
                .font(.caption2)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
 
    private func fieldContainer<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(label)
            content()
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.snow))
        }
    }
 
    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            if isDirty {
                Button("Save changes") { save() }
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
 
                Button("Cancel") { cancelEdits() }
                    .buttonStyle(OutlinedButtonStyle())
            }
 
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("Delete memory")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OutlinedButtonStyle(border: .red))
        }
        .padding(.top, Spacing.sm)
    }
 
    private var savedBanner: some View {
        Text("Saved")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.success, in: Capsule())
            .padding(.top, Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
 
    // MARK: - Actions
 
    private func captureOriginalIfNeeded() {
        guard !hasCapturedOriginal else { return }
        originalTitle = memory.title
        originalTranscript = memory.transcript
        originalDate = memory.date
        originalPhotoFileName = memory.photoFileName
        originalAudioFileName = memory.audioFileName
        hasCapturedOriginal = true
    }
 
    private func markDirty() {
        isDirty = true
    }
 
    private func save() {
        // Now that the new photo/audio are confirmed, it's safe to clean up
        // whatever they replaced.
        if memory.photoFileName != originalPhotoFileName, let originalPhotoFileName {
            FileStorageService.deletePhoto(fileName: originalPhotoFileName)
        }
        if memory.audioFileName != originalAudioFileName {
            FileStorageService.deleteAudio(fileName: originalAudioFileName)
        }
 
        try? context.save()
        isDirty = false
        updateOriginalBaseline()
 
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showSavedConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showSavedConfirmation = false }
        }
    }
 
    private func cancelEdits() {
        // Discard whatever replaced the original photo/audio — it was never
        // confirmed with Save, so it shouldn't be left on disk.
        if memory.photoFileName != originalPhotoFileName, let newPhoto = memory.photoFileName {
            FileStorageService.deletePhoto(fileName: newPhoto)
        }
        if memory.audioFileName != originalAudioFileName {
            FileStorageService.deleteAudio(fileName: memory.audioFileName)
        }
 
        memory.title = originalTitle
        memory.transcript = originalTranscript
        memory.date = originalDate
        memory.photoFileName = originalPhotoFileName
        memory.audioFileName = originalAudioFileName
        isDirty = false
    }
 
    /// After a successful save, the just-saved values become the new
    /// "original" baseline, so a later edit-then-Cancel in the same session
    /// reverts to this point rather than the very first values loaded.
    private func updateOriginalBaseline() {
        originalTitle = memory.title
        originalTranscript = memory.transcript
        originalDate = memory.date
        originalPhotoFileName = memory.photoFileName
        originalAudioFileName = memory.audioFileName
    }
 
    private func toggleFavourite() {
        memory.isFavourite.toggle()
        try? context.save()
    }
 
    private func delete() {
        // There's no "recently deleted" screen or purge job that ever acts on
        // isDeleted/deletedAt, so soft-deleting only hid the memory from the
        // Archive list — the record (and its files) stuck around forever.
        // Delete for real.
        FileStorageService.deleteAudio(fileName: memory.audioFileName)
        if let photoFileName = memory.photoFileName {
            FileStorageService.deletePhoto(fileName: photoFileName)
        }
 
        context.delete(memory)
        try? context.save()
 
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
 
    private func attachPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        if let fileName = try? FileStorageService.savePhoto(data: data) {
            memory.photoFileName = fileName
            markDirty()
        }
    }
 
    private func removePhoto() {
        memory.photoFileName = nil
        markDirty()
    }
 
    /// Called when re-recording finishes. `audioFileName` has already been
    /// moved into FileStorageService's shared container by the
    /// `audioReplacement` modifier. Transcript is nil if transcription
    /// failed or wasn't available — keep the old transcript rather than
    /// blanking it out. Both are revertible via Cancel until Save is pressed.
    private func replaceAudio(fileName audioFileName: String, transcript: String?) {
        memory.audioFileName = audioFileName
        if let transcript {
            memory.transcript = transcript
        }
        markDirty()
    }
}
 
/// Wraps the Recording track's `PhotoAttachmentView` (which binds a plain
/// `UIImage?`) so it can be presented as a sheet here with a Done button,
/// rather than duplicating photo-picking logic.
private struct AddPhotoSheet: View {
    let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
 
    var body: some View {
        NavigationStack {
            VStack {
                PhotoAttachmentView(image: $image)
                    .padding(Spacing.lg)
                Spacer()
            }
            .background(AppColor.screenBackground.ignoresSafeArea())
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let image { onPicked(image) }
                        dismiss()
                    }
                    .disabled(image == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
 
/// Lightweight on-disk playback for a saved memory's audio file. Separate
/// from the Recording track's AVPlayer-based scrubbing player in
/// SaveMemoryView — this only needs play/pause + a progress bar, not
/// recording or assembly.
@MainActor
final class MemoryAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
 
    private var player: AVAudioPlayer?
    private var loadedFileName: String?
    private var timer: Timer?
 
    func togglePlayback(fileName: String) {
        if isPlaying {
            pause()
        } else {
            play(fileName: fileName)
        }
    }
 
    private func play(fileName: String) {
        let url = FileStorageService.audioURL(for: fileName)
        do {
            // Recreate the player if the file changed (e.g. after re-record)
            // instead of forever caching the first file it played, which was
            // leaving playback stuck on the old audio.
            if player == nil || loadedFileName != fileName {
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self
                loadedFileName = fileName
                progress = 0
            }
            player?.play()
            isPlaying = true
            startTimer()
        } catch {
            isPlaying = false
        }
    }
 
    private func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }
 
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        timer?.invalidate()
    }
 
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
    }
 
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.timer?.invalidate()
        }
    }
}
