//
//  SVGImageView.swift
//  PetApp
//
//  Renders a bundled SVG (vector) crisply at any size using WebKit, which has
//  full SVG support. Used for illustrations that ship as .svg rather than as
//  raster assets or Lottie/Rive animations.
//

import SwiftUI
import UIKit
import WebKit

struct SVGImageView: UIViewRepresentable {
    /// Resource name of the bundled `.svg` (without extension).
    let name: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        load(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func load(into webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg"),
              let svg = try? String(contentsOf: url, encoding: .utf8) else { return }
        // Wrap the SVG so it centers and scales to fit the view with a
        // transparent background, independent of the file's own sizing.
        let html = """
        <!doctype html><html><head><meta name="viewport" \
        content="width=device-width, initial-scale=1, maximum-scale=1"><style>\
        html,body{margin:0;height:100%;background:transparent;}\
        body{display:flex;align-items:center;justify-content:center;}\
        svg{max-width:100%;max-height:100%;height:auto;width:auto;}\
        </style></head><body>\(svg)</body></html>
        """
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }
}
