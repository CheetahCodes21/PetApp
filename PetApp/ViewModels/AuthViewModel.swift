//
//  AuthViewModel.swift
//  PetApp
//
//  Authentication state backed by the Supabase Swift SDK. Handles email
//  sign in/up and Sign in with Apple (id-token exchange). The SDK persists
//  and refreshes the session automatically, so returning users stay signed in.
//

import SwiftUI
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published state

    /// Drives whether the app shows the home screen.
    @Published var isAuthenticated = false
    @Published private(set) var firstName: String = ""
    @Published private(set) var email: String = ""

    // Sign-in form (existing users)
    @Published var loginIdentifier = ""
    @Published var loginPassword = ""
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let auth = SupabaseManager.client.auth

    init() {
        observeInitialSession()
    }

    var canSubmitSignIn: Bool {
        !loginIdentifier.trimmingCharacters(in: .whitespaces).isEmpty
            && loginPassword.count >= 6
    }

    // MARK: - Email sign in (existing users)

    func signIn() {
        guard SupabaseConfig.isConfigured else {
            errorMessage = notConfiguredMessage
            return
        }
        guard canSubmitSignIn else { return }
        errorMessage = nil
        isWorking = true
        Task {
            do {
                let session = try await auth.signIn(email: loginIdentifier,
                                                    password: loginPassword)
                apply(session)
                isWorking = false
                isAuthenticated = true   // returning user → straight to home
            } catch {
                isWorking = false
                errorMessage = friendly(error)
            }
        }
    }

    // MARK: - Email sign up (new users, from registration)

    /// Creates the account. Throws on failure so the caller can stay on the step.
    func signUpWithEmail(email: String, password: String, fullName: String) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        let metadata: [String: AnyJSON]? = fullName.isEmpty
            ? nil
            : ["full_name": .string(fullName)]
        let response = try await auth.signUp(email: email, password: password, data: metadata)
        if let session = response.session {
            apply(session)
        } else {
            // Email confirmation required; no session yet. Onboarding continues.
            self.email = email
        }
        // Note: we do NOT set isAuthenticated here — onboarding continues.
    }

    // MARK: - Sign in with Apple

    func signInWithApple(_ credential: AppleCredential) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        let session = try await auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: credential.idToken,
                nonce: credential.rawNonce))
        apply(session)
        if firstName.isEmpty, !credential.fullName.isEmpty {
            firstName = credential.fullName
        }
    }

    // MARK: - Flow control

    /// Enters the app (used after Apple sign-in from the login screen).
    func enterApp() {
        isAuthenticated = true
    }

    /// Finishes the multi-step registration flow and enters the app.
    func finishOnboarding(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { firstName = trimmed }
        isAuthenticated = true
    }

    func signOut() {
        Task { try? await auth.signOut() }
        isAuthenticated = false
        loginIdentifier = ""
        loginPassword = ""
        firstName = ""
        email = ""
    }

    // MARK: - Session restore

    /// Restores a persisted session on launch (returning users skip onboarding).
    private func observeInitialSession() {
        Task {
            for await change in auth.authStateChanges {
                if change.event == .initialSession, let session = change.session {
                    apply(session)
                    isAuthenticated = true
                }
            }
        }
    }

    private func apply(_ session: Session) {
        if case let .string(name)? = session.user.userMetadata["full_name"], !name.isEmpty {
            firstName = name
        }
        email = session.user.email ?? email
    }

    // MARK: - Helpers

    private var notConfiguredMessage: String {
        "Sign-in isn't set up yet. Add your Supabase key in SupabaseConfig.swift."
    }

    private func friendly(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return "We couldn't sign you in. Please check your details and try again."
    }
}

/// Minimal error used when the Supabase key hasn't been configured.
enum AuthError: LocalizedError {
    case notConfigured
    var errorDescription: String? {
        "Sign-in isn't set up yet. Add your Supabase key in SupabaseConfig.swift."
    }
}
