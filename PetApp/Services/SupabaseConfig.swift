//
//  SupabaseConfig.swift
//  PetApp
//
//  Connection details for the app's Supabase project.
//
//  The `anonKey` is the project's *public* anon key (a JWT beginning with
//  "eyJ..."). It is SAFE to ship in a client app — access is controlled by
//  Row-Level Security on the server. NEVER put the Postgres connection string
//  or the service_role key in the app.
//
//  Find the anon key: Supabase Dashboard → Project Settings → API →
//  Project API keys → `anon` `public`.
//

import Foundation

enum SupabaseConfig {
    static let url = URL(string: "https://sscezgczcgixirxijllt.supabase.co")!

    /// Project publishable (public) key — safe to ship in a client app.
    static let anonKey = "sb_publishable_s5NJ2OW2voHzQIkwjBB4rQ_EnyuLD6Z"

    /// Whether a real anon key has been provided.
    static var isConfigured: Bool {
        !anonKey.hasPrefix("PASTE_") && !anonKey.isEmpty
    }
}
