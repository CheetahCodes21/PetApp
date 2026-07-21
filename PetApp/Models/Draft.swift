//
//  Draft.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//

import Foundation
import SwiftData
 
/// An in-progress or interrupted recording, kept separate from Memory so a
/// crash or backgrounding during recording never loses audio. Promoted to a
/// Memory once the user completes the save flow; deleted on discard.
@Model
final class Draft {
    var id: String
    var audioFileName: String
    var photoFileName: String?
    var transcriptInProgress: String?
    var startedAt: Date
    var lastUpdatedAt: Date
    var isRecoverable: Bool
 
    init(
        id: String = UUID().uuidString,
        audioFileName: String,
        photoFileName: String? = nil,
        transcriptInProgress: String? = nil,
        startedAt: Date = .now,
        lastUpdatedAt: Date = .now,
        isRecoverable: Bool = true
    ) {
        self.id = id
        self.audioFileName = audioFileName
        self.photoFileName = photoFileName
        self.transcriptInProgress = transcriptInProgress
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.isRecoverable = isRecoverable
    }
}
