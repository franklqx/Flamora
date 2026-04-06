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

enum AppConfig {

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
        guard let value = Bundle.main.infoDictionary?[key] as? String,
              !value.isEmpty,
              !value.hasPrefix("$(") // xcconfig 未替换时的占位符
        else {
            fatalError("""
                [AppConfig] Missing or unresolved config key: '\(key)'.

                To fix:
                1. Copy Config.xcconfig.example → Config.xcconfig at the project root.
                2. Fill in the real values in Config.xcconfig.
                3. Make sure Config.xcconfig is referenced in Xcode's project settings
                   (target → Build Settings → Based on Configuration File).
                """)
        }
        return value
    }
}
