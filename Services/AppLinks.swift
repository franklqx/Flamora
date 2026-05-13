//
//  AppLinks.swift
//  Meridian
//
//  Unified legal URLs and trust bridge copy.
//

import Foundation

enum AppLinks {

    // MARK: - Legal URLs
    //
    // ⚠️ LAUNCH BLOCKER for App Store submission:
    // Both URLs MUST resolve (HTTP 200) before submission. Apple verifies them.
    // Currently pointing at flamora.app/{privacy,terms} — deploy the static
    // pages in `landing/` to those paths, or update these constants to a
    // hosted URL (Vercel / GitHub Pages / etc.) before the first ASC build.
    //
    // TestFlight external review also requires Privacy Policy URL in App
    // Store Connect → App Information; the in-app link should match it.
    static let privacyPolicyURL  = URL(string: "https://flamora.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://flamora.app/terms")!

    // MARK: - UserDefaults key
    static let plaidTrustBridgeSeen = "plaidTrustBridgeSeen"

    // MARK: - Trust Bridge Copy
    enum TrustBridge {
        static let title       = "Connect Securely"
        static let body        = "Meridian connects through Plaid, a read-only service used by major financial apps. Your bank credentials are never stored in Meridian."
        static let buttonLabel = "Connect Securely"

        static let badges: [(icon: String, label: String)] = [
            ("lock.shield.fill", "Read-only"),
            ("lock.fill",        "Encrypted"),
            ("building.columns.fill", "Powered by Plaid")
        ]
    }
}
