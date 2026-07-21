//
//  AppleSignIn.swift
//  PetApp
//
//  Native Sign in with Apple: a reusable SwiftUI button that performs the
//  Apple authorization with a nonce and hands back the identity token, which
//  we exchange with Supabase for a session.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AppleCredential {
    let idToken: String
    let rawNonce: String
    let fullName: String
}

enum AppleSignInError: LocalizedError {
    case missingIdentityToken

    var errorDescription: String? {
        "We couldn't read your Apple credentials. Please try again."
    }
}

/// Reads the `sub` claim out of an Apple identity token so the demo
/// `app_users` table has a stable key for "this Apple account", without a
/// server to verify the token against Apple. Fine for this test app; a real
/// backend should verify the token's signature before trusting it.
enum AppleIdentityToken {
    static func subject(from idToken: String) -> String? {
        payload(from: idToken)?["sub"] as? String
    }

    private static func payload(from idToken: String) -> [String: Any]? {
        let segments = idToken.split(separator: ".")
        guard segments.count > 1 else { return nil }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}

enum AppleNonce {
    /// A cryptographically-random nonce string.
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                // Fallback that is still unpredictable enough for a nonce.
                return UUID().uuidString + UUID().uuidString
            }
            for random in randoms where remaining > 0 {
                if Int(random) < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// SHA-256 hex digest, as Apple expects for the request nonce.
    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

/// Apple's native sign-in button. Generates a nonce, requests name + email,
/// and returns an `AppleCredential` on success.
struct AppleSignInButton: View {
    var onResult: (Result<AppleCredential, Error>) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var currentNonce = ""

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = AppleNonce.random()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleNonce.sha256(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard
                    let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = credential.identityToken,
                    let idToken = String(data: tokenData, encoding: .utf8)
                else {
                    onResult(.failure(AppleSignInError.missingIdentityToken))
                    return
                }
                let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                onResult(.success(AppleCredential(idToken: idToken,
                                                  rawNonce: currentNonce,
                                                  fullName: name)))
            case .failure(let error):
                onResult(.failure(error))
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 56)
    }
}
