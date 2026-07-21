//
//  MainTabView.swift
//  PetApp
//
//  The signed-in shell: Home, Archive, and Settings with a custom bottom
//  navigation bar sized for easy tapping.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, archive, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:     return "Home"
        case .archive:  return "Archive"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:     return "house.fill"
        case .archive:  return "books.vertical.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @State private var tab: AppTab = .home

    var body: some View {
        Group {
            switch tab {
            case .home:     HomeView()
            case .archive:  ArchiveView()
            case .settings: SettingsView(showsBack: false)
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomNavBar(selection: $tab)
        }
    }
}

private struct BottomNavBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                button(for: tab)
            }
        }
        .padding(.top, Spacing.xs)
        .background(navBackground)
        .overlay(alignment: .top) {
            Divider().overlay(AppColor.textSecondary.opacity(0.15))
        }
    }

    private func button(for tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.title2)
                Text(tab.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? AppColor.purple : AppColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var navBackground: some View {
        AppColor.surface
            .shadow(color: .black.opacity(0.08), radius: 6, y: -2)
            .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppSettings())
        .environmentObject(CompanionStore())
}
