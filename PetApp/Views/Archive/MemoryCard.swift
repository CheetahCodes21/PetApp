//
//  MemoryCard.swift
//  PetApp
//
//  Created by Yijia Sang on 21/7/2026.
//

import SwiftUI

struct MemoryCard: View {

    @Bindable var memory: Memory

    var body: some View {

        HStack {

            VStack(alignment: .leading, spacing: 6) {

                Text(memory.title.isEmpty ? "Untitled Memory" : memory.title)
                    .font(.headline)

                Text(memory.date.formatted(date: .abbreviated,
                                           time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(memory.transcript)
                    .lineLimit(2)
                    .font(.subheadline)

            }

            Spacer()

            if memory.isFavourite {

                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)

            }

        }
        .padding(.vertical, 8)

    }

}
