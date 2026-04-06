//
//  AppLinks.swift
//  Flamora app
//
//  Unified legal URLs and trust bridge copy.
//  Replace the placeholder URLs below with live links before App Store submission.
//

import Foundation

enum AppLinks {

    // MARK: - Legal URLs
    // TODO: Replace with live URLs before App Store submission.
    static let privacyPolicyURL  = URL(string: "https://flamora.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://flamora.app/terms")!

    // MARK: - UserDefaults key
    static let plaidTrustBridgeSeen = "plaidTrustBridgeSeen"

    // MARK: - Trust Bridge Copy
    enum TrustBridge {
        static let title       = "Connect Securely"
        static let body        = "Flamora connects through Plaid, a read-only service used by major financial apps. Your bank credentials are never stored in Flamora."
        static let buttonLabel = "Connect Securely"

        static let badges: [(icon: String, label: String)] = [
            ("lock.shield.fill", "Read-only"),
            ("lock.fill",        "Encrypted"),
            ("building.columns.fill", "Powered by Plaid")
        ]
    }
}
