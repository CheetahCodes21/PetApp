//
//  ContentView.swift
//  PetApp
//
//  Root router: shows the auth / onboarding flow until the user is
//  authenticated, then a placeholder home. App-wide preferences
//  (text size, theme, language) are applied here so every screen honors them.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var settings = AppSettings()
    @StateObject private var companionStore = CompanionStore()

    var body: some View {
        Group {
            if auth.isAuthenticated {
                HomePlaceholderView()
            } else {
                AuthFlowView()
            }
        }
        .environmentObject(auth)
        .environmentObject(settings)
        .environmentObject(companionStore)
        .preferredColorScheme(settings.theme.colorScheme)
        .dynamicTypeSize(settings.textSize.dynamicTypeSize)
        .environment(\.locale, settings.language.locale)
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}

/// Coordinates the unauthenticated screens with a navigation stack.
private struct AuthFlowView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var settings: AppSettings

    private enum Route: Hashable {
        case login
        case signIn
        case register
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onCreateAccount: { path.append(.register) },
                onLogIn: { path.append(.login) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .login:
                    LoginView(onContinueWithEmail: { path.append(.signIn) })
                case .signIn:
                    SignInView()
                case .register:
                    RegistrationFlowView(
                        onComplete: { auth.finishOnboarding(name: settings.name) },
                        onCancel: { if !path.isEmpty { path.removeLast() } }
                    )
                }
            }
        }
        .tint(AppColor.heading)
    }
}

/// Minimal signed-in landing so the flow has somewhere to arrive.
/// Replaced later by the real home screen; hosts the Settings entry point.
private struct HomePlaceholderView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var settings: AppSettings

    // TEMP (Dev 3, KAN-19): local test entry for the recording flow. The real
    // main screen is Dev 2's; their Record button replaces this button and
    // reuses the same `.memoryRecorder` / `.recordingRecovery` modifiers.
    @State private var showRecording = false
    // TEMP (Dev 3): set when a recording is kept, then handed to the memory
    // screen. Dev 4's real archive/detail screen replaces the placeholder below.
    @State private var savedDraft: RecordingDraft?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.surface.ignoresSafeArea()
                VStack(spacing: Spacing.lg) {
                    Text("🐤")
                        .font(.system(size: 88))
                    Text("Welcome, \(greetingName)!")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Your home screen will live here.")
                        .font(.title3)
                        .foregroundStyle(AppColor.textSecondary)
                    // TEMP (Dev 3): stand-in for Dev 2's Record button.
                    Button {
                        showRecording = true
                    } label: {
                        Label("Record a memory", systemImage: "mic.fill")
                    }
                    .buttonStyle(FilledButtonStyle(background: AppColor.purple))
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.top, Spacing.lg)
                    Button("Sign out", action: auth.signOut)
                        .buttonStyle(OutlinedButtonStyle())
                        .padding(.horizontal, Spacing.xxl)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(AppColor.purple)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            // TEMP (Dev 3): where Dev 4's memory screen opens after keeping a
            // recording.
            .navigationDestination(item: $savedDraft) { draft in
                MemoryDestinationPlaceholder(draft: draft)
            }
        }
        // Dev 3 integration surface — the whole recording feature in two lines.
        // KAN-19 hands back a finished draft; KAN-20 will swap this for the save
        // sheet that produces a saved memory.
        .memoryRecorder(isPresented: $showRecording) { draft in savedDraft = draft }
        .recordingRecovery { draft in savedDraft = draft }
    }

    private var greetingName: String {
        if !settings.name.isEmpty { return settings.name }
        return auth.firstName.isEmpty ? "friend" : auth.firstName
    }
}

/// TEMP (Dev 3): stands in for Dev 4's memory screen. It only proves the
/// handoff works — a kept recording produces a `RecordingDraft` that the memory
/// screen receives. Dev 4 replaces this with the real archive/detail screen.
private struct MemoryDestinationPlaceholder: View {
    let draft: RecordingDraft

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Text("Kept")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColor.success)
                Text("Dev 4's memory screen opens here.")
                    .font(.title3)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: Spacing.xs) {
                    Text("Length: \(RecordingView.timeString(draft.duration))")
                    Text("Segments: \(draft.segmentFileNames.count)")
                    Text("Recorded: \(draft.createdAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, Spacing.md)
            }
            .padding()
        }
        .navigationTitle("Memory")
    }
}

#Preview {
    ContentView()
}
