//
//  SavedMemoryBridge.swift
//  PetApp
//
//  Created by Yijia Sang on 22/7/2026.
//

//
//  SavedMemoryBridge.swift
//  PetApp
//
//  Converts the Recording track's temporary `SavedMemory` (see SavedMemory.swift's
//  header — it's an intentional stub) into a real, persisted `Memory`. This is
//  the hookup that stub was waiting on; once every save path goes through here,
//  `SavedMemory`/`MemoryStore` can be deleted.
//
//  Also handles a real integration gap: `SavedMemory`'s audio/photo files are
//  written to `MemoryStore`'s own app-private directory, but `FileStorageService`
//  (and therefore the Archive/widgets/export code that reads `Memory.audioFileName`
//  and `Memory.photoFileName`) expects them in the shared App Group container.
//  Without copying the bytes across here, a saved memory would show up in
//  Archive with a filename that resolves to nothing.
//
 
import Foundation
import SwiftData
 
extension SavedMemory {
    @discardableResult
    func persist(in context: ModelContext, companion: Companion? = nil) throws -> Memory {
        let audioData = try Data(contentsOf: MemoryStore.shared.audioURL(named: audioFileName))
        let newAudioFileName = try FileStorageService.saveAudio(data: audioData, fileName: audioFileName)
 
        var newPhotoFileName: String?
        if let photoFileName {
            let photoData = try Data(contentsOf: MemoryStore.shared.photoURL(named: photoFileName))
            newPhotoFileName = try FileStorageService.savePhoto(data: photoData, fileName: photoFileName)
        }
 
        let memory = Memory(
            id: id,
            title: title,
            transcript: transcript,
            date: createdAt,
            createdAt: createdAt,
            audioFileName: newAudioFileName,
            photoFileName: newPhotoFileName,
            companion: companion
        )
        context.insert(memory)
        try context.save()
        return memory
    }
}
