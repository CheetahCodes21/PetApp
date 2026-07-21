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

        NavigationStack {

            VStack(spacing: 16) {

                Picker("", selection: $favouritesOnly) {

                    Text("All")
                        .tag(false)

                    Text("Favourites")
                        .tag(true)

                }
                .pickerStyle(.segmented)

                TextField("Search memories...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if memories.isEmpty {

                    ContentUnavailableView(
                        "No Memories",
                        systemImage: "books.vertical",
                        description: Text("Record your first memory.")
                    )

                } else {

                    List {

                        ForEach(memories) { memory in

                            NavigationLink {

                                MemoryDetailView(memory: memory)

                            } label: {

                                MemoryCard(memory: memory)

                            }

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
