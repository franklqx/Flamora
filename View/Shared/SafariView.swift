//
//  SafariView.swift
//  Meridian
//
//  Thin UIViewControllerRepresentable wrapper around SFSafariViewController.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        // `preferredControlTintColor` is deprecated on iOS 26+ (tint fights system chrome).
        // Rely on system Safari appearance for a stable build across SDKs.
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
