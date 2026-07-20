//
//  SupabaseManager.swift
//  PetApp
//
//  Shared Supabase client. The SDK persists and refreshes the auth session
//  automatically, and gives us database + storage access for later features
//  (saving memories, companion data, photos/audio).
//

import Foundation
import Supabase

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
