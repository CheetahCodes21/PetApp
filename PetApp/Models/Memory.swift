//
//  Memory.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//

import Foundation
import SwiftData
 
/// A saved journal entry. Audio and photos live as files on disk in the
/// shared App Group container (see FileStorageService) — only filenames
/// are stored here, never raw bytes.
@Model
final class Memory {
    var id: String
    var title: String
    var transcript: String
    var date: Date          // editable by the user; defaults to recording date
    var createdAt: Date
 
    var audioFileName: String
    var photoFileName: String?
 
    var isFavourite: Bool
    var isDeleted: Bool     // soft delete, pairs with a later purge job
    var deletedAt: Date?
 
    var companion: Companion?

    /// The signed-in user's id (UUID string) at save time. Stamped directly so
    /// a memory is always attributable to its owner, even if the companion
    /// relationship is missing — this is what Home/Archive filter on. Optional
    /// for lightweight migration of memories saved before this field existed.
    var ownerId: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        transcript: String,
        date: Date = .now,
        createdAt: Date = .now,
        audioFileName: String,
        photoFileName: String? = nil,
        isFavourite: Bool = false,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        companion: Companion? = nil,
        ownerId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.transcript = transcript
        self.date = date
        self.createdAt = createdAt
        self.audioFileName = audioFileName
        self.photoFileName = photoFileName
        self.isFavourite = isFavourite
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.companion = companion
        self.ownerId = ownerId
    }
}

