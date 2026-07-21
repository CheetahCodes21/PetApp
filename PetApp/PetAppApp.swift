//
//  PetAppApp.swift
//  PetApp
//
//  Created by Maroor Chethan Pai on 16/7/2026.
//

import SwiftUI
import SwiftData

@main
struct PetAppApp: App {
    let modelContainer = MemoMeSchema.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
