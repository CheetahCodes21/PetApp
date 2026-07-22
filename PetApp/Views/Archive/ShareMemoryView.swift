

//
//  ShareMemoryView.swift
//  PetApp
//
//  The share popup: a summary card of the memory, with "Save as Photo" and
//  "Share" (native share sheet — Messages, Mail, etc.) options, plus an
//  exit/cross button.
//
 
import SwiftUI
import UIKit
 
struct ShareMemoryView: View {
    let memory: Memory
 
    @Environment(\.dismiss) private var dismiss
    @State private var showActivitySheet = false
    @State private var savedConfirmation = false
 
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                summaryCard
                    .padding(.top, Spacing.md)
 
                VStack(spacing: Spacing.sm) {
                    Button {
                        saveAsPhoto()
                    } label: {
                        Label("Save as Photo", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OutlinedButtonStyle())
 
                    Button {
                        showActivitySheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FilledButtonStyle(background: AppColor.ninja))
                }
                .padding(.horizontal, Spacing.lg)
 
                if savedConfirmation {
                    Text("Saved to Photos")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.success)
                }
 
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .background(AppColor.screenBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivityShareSheet(items: shareItems)
            }
        }
    }
 
    // MARK: - Summary card
 
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let photoFileName = memory.photoFileName,
               let uiImage = UIImage(contentsOfFile: FileStorageService.photoURL(for: photoFileName).path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
 
            Text(memory.title.isEmpty ? "Untitled memory" : memory.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
 
            Text(memory.date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
 
            if !memory.transcript.isEmpty {
                Text(memory.transcript)
                    .font(.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(6)
            }
        }
        .padding(Spacing.lg)
        .background(RoundedRectangle(cornerRadius: 20).fill(AppColor.snow))
        .padding(.horizontal, Spacing.lg)
    }
 
    // MARK: - Actions
 
    private var shareText: String {
        "\(memory.title)\n\(memory.date.formatted(date: .abbreviated, time: .omitted))\n\n\(memory.transcript)"
    }
 
    /// Built explicitly rather than `[shareText, cardImage].compactMap { $0 }`
    /// — boxing a `UIImage?` straight into `[Any]` means compactMap can't
    /// filter out a nil (it becomes a non-nil `Any` wrapping an empty
    /// optional), so a missing photo would silently end up in the share sheet.
    private var shareItems: [Any] {
        var items: [Any] = [shareText]
        if let cardImage {
            items.append(cardImage)
        }
        return items
    }
 
    /// Renders the summary card to a UIImage for sharing/saving, using the
    /// same content shown on screen.
    private var cardImage: UIImage? {
        let renderer = ImageRenderer(content: summaryCard.frame(width: 340))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
 
    private func saveAsPhoto() {
        guard let image = cardImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { savedConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { savedConfirmation = false }
        }
    }
}
 
/// Thin wrapper around UIActivityViewController for the native share sheet.
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
 
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
 
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
