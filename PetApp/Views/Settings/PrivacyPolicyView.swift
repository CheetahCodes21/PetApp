//
//  PrivacyPolicyView.swift
//  PetApp
//
//  Displays the bundled MemoMe privacy policy (privacy-policy.html) in a web
//  view, presented from Settings. The HTML is fully self-contained (inline CSS,
//  no network access needed), so it renders offline.
//

import SwiftUI
import UIKit
import WebKit

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let url = Bundle.main.url(forResource: "privacy-policy", withExtension: "html") {
                    PolicyWebView(fileURL: url)
                } else {
                    ContentUnavailableView("Privacy Policy unavailable",
                                           systemImage: "doc.text",
                                           description: Text("The policy could not be loaded."))
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// A read-only web view that loads a local HTML file, with network loads
/// disabled so the offline policy can never reach out.
private struct PolicyWebView: UIViewRepresentable {
    let fileURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

#Preview {
    PrivacyPolicyView()
}
