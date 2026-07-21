//
//  ArchiveView.swift
//  PetApp
//
//  The memory archive. Full grid/search/edit is future work; for now it lists
//  saved memories or shows a warm empty state.
//

import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject private var memories: MemoryStore

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()

            if memories.memories.isEmpty {
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
                .foregroundStyle(AppColor.purple.opacity(0.6))
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

                ForEach(memories.memories) { memory in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.title.isEmpty ? "Untitled memory" : memory.title)
                            .font(.headline)
                            .foregroundStyle(AppColor.textPrimary)
                        Text(memory.date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
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
    ArchiveView().environmentObject(MemoryStore())
}
