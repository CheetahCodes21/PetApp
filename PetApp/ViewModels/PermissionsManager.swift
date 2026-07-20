//
//  PermissionsManager.swift
//  PetApp
//
//  Requests and reports the system permissions MemoMe needs: microphone
//  (voice recording), camera and photo library (memory photos), and
//  notifications (gentle reminders).
//

import SwiftUI
import Combine
import AVFoundation
import Photos
import UserNotifications

enum PermissionState {
    case notDetermined
    case granted
    case denied

    var isDecided: Bool { self != .notDetermined }
}

enum AppPermission: String, CaseIterable, Identifiable {
    case microphone, camera, photos, notifications
    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone:    return "Microphone"
        case .camera:        return "Camera"
        case .photos:        return "Photo Library"
        case .notifications: return "Notifications"
        }
    }

    var explanation: String {
        switch self {
        case .microphone:    return "To record your memories in your own voice."
        case .camera:        return "To take a photo to go with a memory."
        case .photos:        return "To add a picture from your library to a memory."
        case .notifications: return "For gentle reminders and your daily question."
        }
    }

    var systemImage: String {
        switch self {
        case .microphone:    return "mic.fill"
        case .camera:        return "camera.fill"
        case .photos:        return "photo.fill"
        case .notifications: return "bell.fill"
        }
    }
}

@MainActor
final class PermissionsManager: ObservableObject {
    @Published var states: [AppPermission: PermissionState] = [:]

    init() {
        for permission in AppPermission.allCases {
            states[permission] = .notDetermined
        }
        refresh()
    }

    func state(for permission: AppPermission) -> PermissionState {
        states[permission] ?? .notDetermined
    }

    /// Refreshes current statuses without prompting.
    func refresh() {
        // Microphone
        switch AVAudioApplication.shared.recordPermission {
        case .granted: states[.microphone] = .granted
        case .denied:  states[.microphone] = .denied
        default:       states[.microphone] = .notDetermined
        }

        // Camera
        states[.camera] = map(AVCaptureDevice.authorizationStatus(for: .video))

        // Photos
        states[.photos] = mapPhotos(PHPhotoLibrary.authorizationStatus(for: .readWrite))

        // Notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let value: PermissionState
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: value = .granted
            case .denied:                               value = .denied
            default:                                    value = .notDetermined
            }
            Task { @MainActor in self.states[.notifications] = value }
        }
    }

    /// Prompts for a single permission (no-op if already decided).
    func request(_ permission: AppPermission) async {
        switch permission {
        case .microphone:
            let granted = await AVAudioApplication.requestRecordPermission()
            states[.microphone] = granted ? .granted : .denied

        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            states[.camera] = granted ? .granted : .denied

        case .photos:
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            states[.photos] = mapPhotos(status)

        case .notifications:
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            states[.notifications] = granted ? .granted : .denied
        }
    }

    /// Prompts for every permission that hasn't been decided yet, in order.
    func requestAll() async {
        for permission in AppPermission.allCases where state(for: permission) == .notDetermined {
            await request(permission)
        }
    }

    // MARK: - Mapping helpers

    private func map(_ status: AVAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized:          return .granted
        case .denied, .restricted: return .denied
        default:                   return .notDetermined
        }
    }

    private func mapPhotos(_ status: PHAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized, .limited: return .granted
        case .denied, .restricted:  return .denied
        default:                    return .notDetermined
        }
    }
}
