//
//  MemoryDetailView.swift
//  PetApp
//
//  View and edit a saved memory: title, date, photo, transcript, and audio
//  playback, plus favourite, delete (with confirmation), and share. Editing
//  is inline — there's no separate "edit mode" screen, matching how the
//  rest of the app (e.g. onboarding) handles editable forms.
//
 
import SwiftUI
import SwiftData
import UIKit
import AVFoundation
 
struct MemoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
 
    @Bindable var memory: Memory
 
    @State private var isDirty = false
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showPhotoPicker = false
    @State private var showSavedConfirmation = false
    @StateObject private var player = MemoryAudioPlayer()
 
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                photoSection
                titleField
                dateField
                transcriptField
                audioSection
            }
            .padding(Spacing.lg)
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
        .safeAreaInset(edge: .bottom) { bottomBar }
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
        .onDisappear { player.stop() }
    }
 
    // MARK: - Sections
 
    @ViewBuilder
    private var photoSection: some View {
        Group {
            if let photoFileName = memory.photoFileName,
               let uiImage = UIImage(contentsOfFile: FileStorageService.photoURL(for: photoFileName).path) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
 
                    Button {
                        removePhoto()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .padding(8)
                    }
                    .accessibilityLabel("Delete photo")
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
            DatePicker("", selection: Binding(
                get: { memory.date },
                set: { memory.date = $0; markDirty() }
            ), displayedComponents: .date)
            .labelsHidden()
        }
    }
 
    private var transcriptField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What you shared")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
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
        VStack(spacing: Spacing.sm) {
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
            }
        }
        .padding(Spacing.sm)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.snow))
    }
 
    private func fieldContainer<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
            content()
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.snow))
        }
    }
 
    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            if isDirty {
                Button("Save changes") { save() }
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
            }
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("Delete memory")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OutlinedButtonStyle(border: .red))
        }
        .padding(Spacing.lg)
        .background(AppColor.snow.opacity(0.98))
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
 
    private func markDirty() {
        isDirty = true
    }
 
    private func save() {
        try? context.save()
        isDirty = false
 
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showSavedConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showSavedConfirmation = false }
        }
    }
 
    private func toggleFavourite() {
        memory.isFavourite.toggle()
        try? context.save()
    }
 
    private func delete() {
        // Soft delete so a purge job (or future "recently deleted") can
        // still recover it — matches the isDeleted field's intent.
        memory.isDeleted = true
        memory.deletedAt = .now
        try? context.save()
 
        FileStorageService.deleteAudio(fileName: memory.audioFileName)
        if let photoFileName = memory.photoFileName {
            FileStorageService.deletePhoto(fileName: photoFileName)
        }
 
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
        if let photoFileName = memory.photoFileName {
            FileStorageService.deletePhoto(fileName: photoFileName)
        }
        memory.photoFileName = nil
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
            if player == nil {
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self
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
        isPlaying = false
        timer?.invalidate()
    }
 
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player, player.duration > 0 else { return }
            Task { @MainActor in
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
