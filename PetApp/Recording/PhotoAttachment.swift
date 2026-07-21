//
//  PhotoAttachment.swift
//  PetApp
//
//  Attach one photo to a memory (KAN-21, US-017): choose from the library
//  (PhotosPicker — no permission prompt needed) or take a new photo (camera,
//  gated through the shared PermissionsManager). The photo can be replaced or
//  removed. Camera is hidden on devices without one (e.g. the simulator).
//

import SwiftUI
import PhotosUI
import UIKit

struct PhotoAttachmentView: View {
    @Binding var image: UIImage?

    // Reuses the team's PermissionsManager rather than duplicating permission code.
    @StateObject private var permissions = PermissionsManager()
    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraDenied = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Photo (optional)")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Attached photo")
            }

            HStack(spacing: Spacing.md) {
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label(image == nil ? "Choose from Library" : "Change from Library",
                          systemImage: "photo.on.rectangle")
                }
                .foregroundStyle(AppColor.purple)

                if cameraAvailable {
                    Button {
                        takePhoto()
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    .foregroundStyle(AppColor.purple)
                }

                if image != nil {
                    Button(role: .destructive) {
                        image = nil
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .font(.callout.weight(.medium))

            if cameraDenied {
                deniedHint
            }
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    image = picked
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { captured in image = captured }
                .ignoresSafeArea()
        }
    }

    private var deniedHint: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("The camera is turned off for MemoMe. You can turn it on in Settings.")
                .font(.callout)
                .foregroundStyle(AppColor.textSecondary)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppColor.purple)
            }
        }
    }

    private func takePhoto() {
        Task {
            if permissions.state(for: .camera) == .notDetermined {
                await permissions.request(.camera)
            }
            switch permissions.state(for: .camera) {
            case .granted:
                cameraDenied = false
                showCamera = true
            case .denied:
                cameraDenied = true
            case .notDetermined:
                break
            }
        }
    }
}

/// Minimal camera capture wrapper (SwiftUI has no native camera view).
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        nonisolated func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            MainActor.assumeIsolated {
                if let image { parent.onCapture(image) }
                parent.dismiss()
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            MainActor.assumeIsolated { parent.dismiss() }
        }
    }
}
