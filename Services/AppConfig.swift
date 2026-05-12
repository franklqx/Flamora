//
//  AppConfig.swift
//  Flamora app
//
//  统一配置读取层。所有 secrets 通过 xcconfig → Info.plist → Bundle 读取，
//  不在源码中硬编码。
//
//  本地开发：拷贝 Config.xcconfig.example → Config.xcconfig，填入真实值。
//  Config.xcconfig 已加入 .gitignore，不会提交到仓库。
//

import Foundation
import os

enum AppConfig {

    private static let log = Logger(subsystem: "com.flamora.app", category: "AppConfig")

    // MARK: - Supabase

    /// Supabase 项目 URL，例如 https://xxxxx.supabase.co
    static var supabaseURL: String { required("SUPABASE_URL") }

    /// Supabase anon（public）JWT key
    static var supabaseAnonKey: String { required("SUPABASE_ANON_KEY") }

    /// Supabase Edge Functions base URL（= supabaseURL/functions/v1）
    static var supabaseFunctionsBaseURL: String {
        "\(supabaseURL)/functions/v1"
    }

    // MARK: - RevenueCat

    /// RevenueCat SDK API key（Platform key，不是 secret key）
    static var revenueCatAPIKey: String { required("REVENUECAT_API_KEY") }

    // MARK: - Private

    private static func required(_ key: String) -> String {
        let raw = Bundle.main.infoDictionary?[key] as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let isMissing = trimmed.isEmpty
            || trimmed.hasPrefix("$(") // xcconfig 未替换时的占位符
            || looksLikeExamplePlaceholder(trimmed)

        if isMissing {
            // DEBUG: trip an assertion so the developer notices immediately.
            // Release / TestFlight: log and return empty so the app degrades
            // gracefully (API calls will fail and surface a friendly error)
            // instead of hard-crashing on launch.
            assertionFailure("""
                [AppConfig] Missing or unresolved config key: '\(key)'.

                To fix:
                1. Copy Config.xcconfig.example → Config.xcconfig at the project root.
                2. Fill in the real values in Config.xcconfig (not the example placeholder).
                3. Make sure Config.xcconfig is referenced in Xcode's project settings
                   (target → Build Settings → Based on Configuration File).
                """)
            log.error("Missing or unresolved config key: \(key, privacy: .public)")
            return ""
        }

        return trimmed
    }

    private static func looksLikeExamplePlaceholder(_ value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized.hasPrefix("your_") && normalized.hasSuffix("_here")
    }
}
