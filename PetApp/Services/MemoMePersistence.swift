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
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
 
