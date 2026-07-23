//
//  AuthViewModel.swift
//  PetApp
//
//  DEMO AUTH: reads/writes a plain `app_users` table via the Supabase
//  PostgREST API instead of using Supabase Auth. There are no real users
//  yet, so accounts are just rows (email/password/full_name/apple_sub) and
//  "being signed in" just means we've cached that row's id locally. This is
//  not secure (plain-text passwords, wide-open RLS) and must not be reused
//  once the app has real user data — see the SQL in the table's comment
//  block below for the schema this expects.
//
//  Required table (run once in the Supabase SQL editor):
//
//  create table public.app_users (
//    id uuid primary key default gen_random_uuid(),
//    email text unique,
//    password text,
//    full_name text,
//    apple_sub text unique,
//    created_at timestamptz not null default now()
//  );
//  alter table public.app_users enable row level security;
//  create policy "app_users demo access" on public.app_users
//    for all to anon using (true) with check (true);
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
    @Published private(set) var userId: UUID?

    // Sign-in form (existing users)
    @Published var loginIdentifier = ""
    @Published var loginPassword = ""
    @Published var isWorking = false
    @Published var errorMessage: String?

    /// Must be a fresh builder per query: `PostgrestQueryBuilder` is a class
    /// and each `.select`/`.insert`/`.eq` mutates it in place, so a stored
    /// instance would accumulate filters from every earlier request and
    /// silently match zero rows.
    private var table: PostgrestQueryBuilder { SupabaseManager.client.from("app_users") }

    private let defaults = UserDefaults.standard
    private let cacheKey = "auth.cachedUser"

    /// What we persist locally so a returning user is remembered "forever"
    /// (until sign-out) without needing a real session/token.
    private struct CachedUser: Codable {
        let id: UUID
        let email: String?
        let fullName: String?
    }

    init() {
        restoreCurrentSession()
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
                let normalizedEmail = loginIdentifier.trimmingCharacters(in: .whitespaces).lowercased()
                let record: AppUserRecord = try await table
                    .select("id, email, full_name, apple_sub")
                    .ilike("email", pattern: normalizedEmail)   // case-insensitive email match
                    .eq("password", value: loginPassword)
                    .single()
                    .execute()
                    .value
                apply(record)
                isWorking = false
                isAuthenticated = true   // returning user → straight to home
            } catch {
                isWorking = false
                errorMessage = "We couldn't find an account with those details."
            }
        }
    }

    // MARK: - Email sign up (new users, from registration)

    /// Creates the account row. Throws on failure so the caller can stay on the step.
    func signUpWithEmail(email: String, password: String, fullName: String) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }

        let normalizedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()

        let existing: [AppUserRecord] = try await table
            .select("id")
            .eq("email", value: normalizedEmail)
            .execute()
            .value
        guard existing.isEmpty else { throw AuthError.emailTaken }

        let newRecord = NewAppUser(email: normalizedEmail,
                                    password: password,
                                    fullName: fullName.isEmpty ? nil : fullName)
        let inserted: AppUserRecord = try await table
            .insert(newRecord)
            .select("id, email, full_name, apple_sub")
            .single()
            .execute()
            .value
        apply(inserted)
        // Note: we do NOT set isAuthenticated here — onboarding continues.
    }

    // MARK: - Sign in with Apple

    func signInWithApple(_ credential: AppleCredential) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sub = AppleIdentityToken.subject(from: credential.idToken) else {
            throw AppleSignInError.missingIdentityToken
        }

        let existing: [AppUserRecord] = try await table
            .select("id, email, full_name, apple_sub")
            .eq("apple_sub", value: sub)
            .execute()
            .value

        if let record = existing.first {
            apply(record)
        } else {
            let newRecord = NewAppUser(email: nil,
                                        password: nil,
                                        fullName: credential.fullName.isEmpty ? nil : credential.fullName,
                                        appleSub: sub)
            let inserted: AppUserRecord = try await table
                .insert(newRecord)
                .select("id, email, full_name, apple_sub")
                .single()
                .execute()
                .value
            apply(inserted)
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
        defaults.removeObject(forKey: cacheKey)
        userId = nil
        isAuthenticated = false
        loginIdentifier = ""
        loginPassword = ""
        firstName = ""
        email = ""
        // Clear the shared widget snapshot so widgets don't keep showing the
        // signed-out user's pet and stats.
        WidgetSync.clear()
    }

    // MARK: - Account management (edit email / password, delete)

    func updateEmail(to newEmail: String) async throws {
        guard let userId else { throw AuthError.notSignedIn }
        let normalized = newEmail.trimmingCharacters(in: .whitespaces).lowercased()
        guard normalized.contains("@") else { throw AuthError.invalidEmail }
        try await table.update(["email": normalized]).eq("id", value: userId.uuidString).execute()
        email = normalized
        cacheCurrentUser()
    }

    func updatePassword(to newPassword: String) async throws {
        guard let userId else { throw AuthError.notSignedIn }
        guard newPassword.count >= 6 else { throw AuthError.weakPassword }
        try await table.update(["password": newPassword]).eq("id", value: userId.uuidString).execute()
    }

    func deleteAccount() async throws {
        guard let userId else { throw AuthError.notSignedIn }
        try await table.delete().eq("id", value: userId.uuidString).execute()
        signOut()
    }

    private func cacheCurrentUser() {
        guard let userId else { return }
        let cached = CachedUser(id: userId,
                                email: email.isEmpty ? nil : email,
                                fullName: firstName.isEmpty ? nil : firstName)
        if let data = try? JSONEncoder().encode(cached) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Session restore

    /// Restores the cached account synchronously on launch so a signed-in
    /// user goes straight to home with no flash of the welcome screen, then
    /// confirms in the background that the row still exists.
    private func restoreCurrentSession() {
        guard let data = defaults.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CachedUser.self, from: data)
        else { return }

        userId = cached.id
        email = cached.email ?? ""
        firstName = cached.fullName ?? ""
        isAuthenticated = true

        Task {
            do {
                let record: AppUserRecord = try await table
                    .select("id, email, full_name, apple_sub")
                    .eq("id", value: cached.id)
                    .single()
                    .execute()
                    .value
                apply(record)
            } catch {
                // Row was deleted (or the table isn't reachable) — don't
                // strand the user on a "signed in" screen with stale data.
                signOut()
            }
        }
    }

    private func apply(_ record: AppUserRecord) {
        userId = record.id
        if let name = record.fullName, !name.isEmpty { firstName = name }
        email = record.email ?? email

        let cached = CachedUser(id: record.id, email: record.email, fullName: record.fullName)
        if let data = try? JSONEncoder().encode(cached) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Helpers

    private var notConfiguredMessage: String {
        "Sign-in isn't set up yet. Add your Supabase key in SupabaseConfig.swift."
    }
}

/// Errors surfaced by the demo table-based auth.
enum AuthError: LocalizedError {
    case notConfigured
    case emailTaken
    case notSignedIn
    case invalidEmail
    case weakPassword

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sign-in isn't set up yet. Add your Supabase key in SupabaseConfig.swift."
        case .emailTaken:
            return "That email is already registered. Try signing in instead."
        case .notSignedIn:
            return "You need to be signed in to do that."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        }
    }
}
