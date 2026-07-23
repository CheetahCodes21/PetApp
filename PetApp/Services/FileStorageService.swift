//
//  FileStorageService.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//
 
import Foundation
 
/// Saves and loads audio/photo files in the shared App Group container, so
/// both the main app and any future widget can read the same files. Only
/// filenames are stored in SwiftData; this resolves them to real file URLs.
enum FileStorageService {
    /// Was a hardcoded placeholder ("group.com.memome.shared") that didn't match
    /// what's actually registered in the entitlements — that would have crashed
    /// the first time anyone saved a photo or audio file. Now points at the same
    /// constant the widgets use, so there's one source of truth.
    private static let appGroupIdentifier = AppGroup.id
 
    private static var containerURL: URL {
        // Prefer the shared App Group container (so widgets can read the files),
        // but fall back to the app's own Documents directory if it's not
        // available. Never crash — a memory must always be savable.
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return url
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
 
    private static var audioDirectory: URL {
        let dir = containerURL.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
 
    private static var photoDirectory: URL {
        let dir = containerURL.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
 
    static func audioURL(for fileName: String) -> URL { audioDirectory.appendingPathComponent(fileName) }
    static func photoURL(for fileName: String) -> URL { photoDirectory.appendingPathComponent(fileName) }
 
    @discardableResult
    static func saveAudio(data: Data, fileName: String = "\(UUID().uuidString).m4a") throws -> String {
        try data.write(to: audioURL(for: fileName))
        return fileName
    }
 
    @discardableResult
    static func savePhoto(data: Data, fileName: String = "\(UUID().uuidString).jpg") throws -> String {
        try data.write(to: photoURL(for: fileName))
        return fileName
    }
 
    static func deleteAudio(fileName: String) { try? FileManager.default.removeItem(at: audioURL(for: fileName)) }
    static func deletePhoto(fileName: String) { try? FileManager.default.removeItem(at: photoURL(for: fileName)) }
}
