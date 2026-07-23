//
//  MemoMePersistence.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//
 
import Foundation
import SwiftData
 
enum MemoMeSchema {
    /// Local-only for now. If the team turns on CloudKit sync later, swap
    /// in a ModelConfiguration with a cloudKitDatabase parameter here —
    /// note that would also require dropping the .unique constraint on
    /// User.id, since CloudKit doesn't support unique constraints.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            User.self,
            Companion.self,
            Memory.self,
            Draft.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            // Every write path (favourite, delete, and the explicit "Save
            // changes" button in Memory detail) already calls context.save()
            // itself. With autosave left on, SwiftData's own debounced save
            // timer could fire while an edit was only meant to be in-memory —
            // e.g. leaving Memory detail via the back button without pressing
            // Save would still end up persisted.
            container.mainContext.autosaveEnabled = false
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
 
