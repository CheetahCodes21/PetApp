//
//  ArchiveView.swift
//  PetApp
//
//  All Memories / Favourites tabs, search, date filter, and the memory
//  list. Reads real data straight from SwiftData via @Query, so it stays
//  live as memories are saved/edited/deleted elsewhere in the app.
//
 
import SwiftUI
import SwiftData
 
struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var auth: AuthViewModel

    @Query(sort: \Memory.date, order: .reverse)
    private var everyMemory: [Memory]

    /// Memories belonging to the signed-in user. Matched by the stamped
    /// `ownerId` (falling back to the companion's owner), and including legacy
    /// memories that predate owner stamping so a user's history never vanishes.
    private var allMemories: [Memory] {
        let uid = auth.userId?.uuidString
        return everyMemory.filter { memory in
            if let owner = memory.ownerId { return owner == uid }
            return memory.companion?.owner?.id == auth.userId || memory.companion == nil
        }
    }
 
    @State private var selectedTab: ArchiveTab = .all
    @State private var searchText = ""
    @State private var dateFilter: DateFilter?
    @State private var showDatePicker = false
    @State private var pendingGranularity: DateFilterGranularity = .day
    @State private var pendingDay = Date()
    @State private var pendingMonth = Calendar.current.component(.month, from: Date())
    @State private var pendingYear = Calendar.current.component(.year, from: Date())
 
    private var memories: [Memory] {
        allMemories
            .filter { !$0.isDeleted }
            .filter { selectedTab == .all || $0.isFavourite }
            .filter { searchText.isEmpty
                || $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.transcript.localizedCaseInsensitiveContains(searchText) }
            .filter { dateFilter == nil || dateFilter!.matches($0.date) }
    }
 
    private var hasAnyMemories: Bool {
        allMemories.contains { !$0.isDeleted }
    }
 
    private var hasAnyFavourites: Bool {
        allMemories.contains { !$0.isDeleted && $0.isFavourite }
    }
 
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()
 
                VStack(spacing: 0) {
                    header
                    tabPicker
                    searchAndFilterBar
 
                    if selectedTab == .all && !hasAnyMemories {
                        emptyState
                    } else if selectedTab == .favourites && !hasAnyFavourites {
                        noFavouritesState
                    } else if memories.isEmpty {
                        noResultsState
                    } else {
                        list
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showDatePicker) { datePickerSheet }
        }
    }
 
    // MARK: - Header
 
    private var header: some View {
        Text("Archive")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
    }
 
    // MARK: - Tabs
 
    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            ForEach(ArchiveTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
 
    // MARK: - Search + date filter
 
    @ViewBuilder
    private var searchAndFilterBar: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                searchField
                filterButton
            }
            if let dateFilter {
                activeFilterChip(for: dateFilter)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
 
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textSecondary)
            TextField("Search memories", text: $searchText)
                .foregroundStyle(AppColor.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.snow))
    }
 
    private var filterButton: some View {
        Button {
            if let dateFilter {
                pendingGranularity = dateFilter.granularity
                pendingDay = dateFilter.date
                pendingMonth = dateFilter.month
                pendingYear = dateFilter.year
            } else {
                pendingGranularity = .day
                pendingDay = Date()
                pendingMonth = Calendar.current.component(.month, from: Date())
                pendingYear = Calendar.current.component(.year, from: Date())
            }
            showDatePicker = true
        } label: {
            Image(systemName: dateFilter == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColor.ninja)
        }
        .accessibilityLabel("Filter by date")
    }
 
    private func activeFilterChip(for filter: DateFilter) -> some View {
        HStack(spacing: 6) {
            Text(filter.label)
                .font(.caption.weight(.medium))
            Button {
                dateFilter = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .accessibilityLabel("Clear date filter")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundStyle(AppColor.ninja)
        .background(AppColor.ninja.opacity(0.15))
        .clipShape(Capsule())
    }
 
    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Picker("Filter by", selection: $pendingGranularity) {
                    ForEach(DateFilterGranularity.allCases) { granularity in
                        Text(granularity.title).tag(granularity)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)
 
                switch pendingGranularity {
                case .day:
                    DatePicker("Choose a date", selection: $pendingDay, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                case .month:
                    monthYearPicker
                case .year:
                    yearPicker
                }
 
                Spacer()
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dateFilter = DateFilter(
                            granularity: pendingGranularity,
                            date: pendingDay,
                            month: pendingMonth,
                            year: pendingYear
                        )
                        showDatePicker = false
                    }
                }
            }
        }
    }
 
    private var monthYearPicker: some View {
        HStack {
            Picker("Month", selection: $pendingMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                }
            }
            .pickerStyle(.wheel)
 
            Picker("Year", selection: $pendingYear) {
                ForEach(yearRange, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
        }
        .padding(.horizontal)
    }
 
    private var yearPicker: some View {
        Picker("Year", selection: $pendingYear) {
            ForEach(yearRange, id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.wheel)
        .padding(.horizontal)
    }
 
    /// Last 100 years through the current year — plenty for this app's
    /// audience without generating an unbounded list.
    private var yearRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 100)...currentYear).reversed()
    }
 
    // MARK: - List + states
 
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(memories) { memory in
                    NavigationLink {
                        MemoryDetailView(memory: memory)
                    } label: {
                        MemoryCard(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.lg)
        }
    }
 
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
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
            Spacer()
        }
        .padding()
    }
 
    private var noFavouritesState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "star")
                .font(.system(size: 56))
                .foregroundStyle(AppColor.ninja.opacity(0.6))
            Text("No favourites yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text("Tap the star on a memory to keep it here for easy access.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
        .padding()
    }
 
    private var noResultsState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.textSecondary)
            Text("No matching memories")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            Text("Try a different search, or clear your filter.")
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
    }
}
 
enum ArchiveTab: String, CaseIterable, Identifiable {
    case all, favourites
    var id: String { rawValue }
    var title: String { self == .all ? "All Memories" : "Favourites" }
}
 
enum DateFilterGranularity: String, CaseIterable, Identifiable {
    case day, month, year
    var id: String { rawValue }
    var title: String {
        switch self {
        case .day: return "Day"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}
 
/// A date filter that matches on just the day, just the month (any year),
/// or just the year — as opposed to always requiring an exact date.
struct DateFilter {
    let granularity: DateFilterGranularity
    let date: Date     // used when granularity == .day
    let month: Int      // 1...12, used when granularity == .month
    let year: Int        // used when granularity == .month or .year
 
    func matches(_ candidate: Date) -> Bool {
        let calendar = Calendar.current
        switch granularity {
        case .day:
            return calendar.isDate(candidate, inSameDayAs: date)
        case .month:
            let components = calendar.dateComponents([.month, .year], from: candidate)
            return components.month == month && components.year == year
        case .year:
            return calendar.component(.year, from: candidate) == year
        }
    }
 
    var label: String {
        switch granularity {
        case .day:
            return date.formatted(date: .abbreviated, time: .omitted)
        case .month:
            let name = Calendar.current.monthSymbols[month - 1]
            return "\(name) \(year)"
        case .year:
            return String(year)
        }
    }
}
 
#Preview {
    ArchiveView()
}
