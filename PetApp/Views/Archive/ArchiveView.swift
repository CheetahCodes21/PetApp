import SwiftUI
import SwiftData

struct ArchiveView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \Memory.date, order: .reverse)
    private var allMemories: [Memory]

    @State private var searchText = ""
    @State private var favouritesOnly = false

    private var memories: [Memory] {

        allMemories
            .filter { !$0.isDeleted }
            .filter {
                !favouritesOnly || $0.isFavourite
            }
            .filter { memory in
                if searchText.isEmpty {
                    return true
                }

                return memory.title.localizedCaseInsensitiveContains(searchText) ||
                       memory.transcript.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

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
                    .listStyle(.plain)

                }

            }
            .padding()
            .navigationTitle("Archives")

        }

    }

}
