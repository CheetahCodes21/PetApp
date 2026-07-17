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
        case createAccount
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onCreateAccount: { path.append(.createAccount) },
                onLogIn: { path.append(.login) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .login:
                    LoginView(onContinueWithEmail: { path.append(.signIn) })
                case .signIn:
                    SignInView()
                case .createAccount:
                    CreateAccountView(
                        onComplete: { draft in
                            settings.seedNameIfEmpty(draft.firstName)
                            auth.completeSignUp(with: draft)
                        },
                        onCancel: { if !path.isEmpty { path.removeLast() } }
                    )
                    .navigationBarBackButtonHidden(true)
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
                    Button("Sign out", action: auth.signOut)
                        .buttonStyle(OutlinedButtonStyle())
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.top, Spacing.lg)
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
        }
    }

    private var greetingName: String {
        if !settings.name.isEmpty { return settings.name }
        return auth.firstName.isEmpty ? "friend" : auth.firstName
    }
}

#Preview {
    ContentView()
}
