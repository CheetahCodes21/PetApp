//
//  User.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//

import Foundation
import SwiftData
 
/// A thin local anchor tied to the authenticated account (`AppUserRecord.id`
/// from the demo `app_users` table — see AuthViewModel.swift). Personal
/// details and accessibility preferences are intentionally NOT duplicated
/// here: those stay owned by AppSettings (UserDefaults) and AppUserRecord
/// (Supabase) respectively, so there's one source of truth for each. This
/// model exists only so Companion/Memory records have something to attach
/// an ownership relationship to.
@Model
final class User {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
 
    @Relationship(deleteRule: .cascade, inverse: \Companion.owner)
    var companions: [Companion] = []
 
    init(id: UUID, createdAt: Date = .now) {
        self.id = id
        self.createdAt = createdAt
    }
}
 
