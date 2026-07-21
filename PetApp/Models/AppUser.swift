//
//  AppUser.swift
//  PetApp
//
//  Demo-only stand-in for a real authenticated user: a plain row in the
//  `app_users` table instead of a Supabase Auth account. Login and
//  registration read/write this table directly with the public anon key,
//  which requires permissive RLS policies on the table (see
//  AuthViewModel.swift). Do not reuse this approach once the app has real
//  users — passwords are stored as plain text.
//

import Foundation


struct AppUserRecord: Codable {
    let id: UUID
    let email: String?
    let fullName: String?
    let appleSub: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case appleSub = "apple_sub"
    }
}

/// Payload for inserting a new row. Kept separate from `AppUserRecord` so a
/// freshly-created account's password is never decoded back into the app.
struct NewAppUser: Encodable {
    var email: String?
    var password: String?
    var fullName: String?
    var appleSub: String?

    enum CodingKeys: String, CodingKey {
        case email, password
        case fullName = "full_name"
        case appleSub = "apple_sub"
    }
}
