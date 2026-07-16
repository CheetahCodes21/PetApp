//
//  ContentView.swift
//  PetApp
//
//  Root router: shows the auth / onboarding flow until the user is
//  authenticated, then a placeholder home. The full home screen,
//  recording, archive, etc. are future work.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()

    var body: some View {
        Group {
            if auth.isAuthenticated {
                HomePlaceholderView()
                    .environmentObject(auth)
            } else {
                AuthFlowView()
                    .environmentObject(auth)
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}

/// Coordinates the unauthenticated screens with a navigation stack.
private struct AuthFlowView: View {
    @EnvironmentObject private var auth: AuthViewModel

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
                        onComplete: { draft in auth.completeSignUp(with: draft) },
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
/// Replaced later by the real home screen.
private struct HomePlaceholderView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Text("🐤")
                    .font(.system(size: 88))
                Text("Welcome, \(auth.displayNameOrDefault)!")
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
    }
}

private extension AuthViewModel {
    var displayNameOrDefault: String {
        firstName.isEmpty ? "friend" : firstName
    }
}

#Preview {
    ContentView()
}
