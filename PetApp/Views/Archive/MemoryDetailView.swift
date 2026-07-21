//
//  MemoryDetailView.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//

import SwiftUI

struct MemoryDetailView: View {

    @State var memory: Memory

    var body: some View {

        Form {

            Section("Title") {

                Text(memory.title)

            }

            Section("Date") {

                Text(memory.date.formatted())

            }

            Section("Transcript") {

                Text("""
Today I went for a lovely walk.
The weather was beautiful.
""")

            }

            Section {

                Button("Play Recording") {

                    // Audio Player

                }

                Button("Edit") {

                    // Navigate to edit page

                }

                Button(role: .destructive) {

                    // Delete memory

                } label: {

                    Text("Delete Memory")

                }

            }

        }

        .navigationTitle(memory.title)

    }

}
