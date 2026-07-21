//
//  SupabaseManager.swift
//  PetApp
//
//  Shared Supabase client. The SDK persists and refreshes the auth session
//  automatically, and gives us database + storage access for later features
//  (saving memories, companion data, photos/audio).
//
//  `db.schema` is pinned to "public" explicitly: some projects' Data API has
//  more than one exposed schema (e.g. "public" and "api"), and whichever one
//  is listed first in Project Settings → Data API → Exposed schemas is used
//  when no schema is specified — which may not be "public". Pinning it here
//  avoids requests silently landing on the wrong schema.
//

import Foundation
import Supabase

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey,
        options: SupabaseClientOptions(db: .init(schema: "public"))
    )
}
