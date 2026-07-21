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
                MainTabView()
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

#Preview {
    ContentView()
}
