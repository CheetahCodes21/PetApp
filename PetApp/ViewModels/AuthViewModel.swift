//
//  AuthViewModel.swift
//  PetApp
//
//  Owns authentication state and drives the login / onboarding flows.
//  No backend yet — sign-in and account creation are simulated locally so
//  the UI can be built and reviewed end-to-end.
//

import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Session

    @Published var isAuthenticated = false
    /// The signed-in user's first name, shown on the home screen.
    @Published private(set) var firstName: String = ""

    // MARK: - Sign-in (existing users)

    @Published var loginIdentifier = ""      // email or phone
    @Published var loginPassword = ""
    @Published var isWorking = false
    @Published var errorMessage: String?

    var canSubmitSignIn: Bool {
        !loginIdentifier.trimmingCharacters(in: .whitespaces).isEmpty
            && !loginPassword.isEmpty
    }

    func signIn() {
        guard canSubmitSignIn else { return }
        errorMessage = nil
        isWorking = true
        // Simulated network round-trip.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.isWorking = false
            self.firstName = "Friend"
            self.isAuthenticated = true
        }
    }

    func continueWith(provider: SocialProvider) {
        errorMessage = nil
        firstName = "Friend"
        isAuthenticated = true
    }

    // MARK: - Account creation (new users)

    func completeSignUp(with draft: SignUpDraft) {
        firstName = draft.firstName.isEmpty ? "Friend" : draft.firstName
        isAuthenticated = true
    }

    func signOut() {
        isAuthenticated = false
        loginIdentifier = ""
        loginPassword = ""
        firstName = ""
    }
}

enum SocialProvider: String, Identifiable {
    case apple, facebook, google
    var id: String { rawValue }
}

/// Collected values while a new user moves through the create-account steps.
struct SignUpDraft {
    var firstName = ""
    var email = ""
    var password = ""
    var companion: Companion?
}
