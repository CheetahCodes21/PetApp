//
//  ArchiveView.swift
//  PetApp
//
//  The memory archive. Full grid/search/edit is future work; for now it lists
//  saved memories (SwiftData) or shows a warm empty state.
//

import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Query(sort: \Memory.date, order: .reverse) private var allMemories: [Memory]

    private var memories: [Memory] {
        allMemories.filter { !$0.isDeleted }
    }

    var body: some View {
        ZStack {
            AppColor.snow.ignoresSafeArea()

            if memories.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.ninja.opacity(0.6))
            Text("Your memories will live here")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text("Once you record a memory, you'll find it here to listen back to, search, and treasure.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, Spacing.xl)
        }
        .padding()
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Memories")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)

                ForEach(memories) { memory in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memory.title.isEmpty ? "Untitled memory" : memory.title)
                                .font(.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            Text(memory.date, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        Spacer()
                        if memory.isFavourite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(AppColor.ninja)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(Spacing.lg)
        }
    }
}

#Preview {
    ArchiveView()
        .modelContainer(for: [Memory.self], inMemory: true)
}
