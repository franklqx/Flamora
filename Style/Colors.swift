//
//  Colors.swift
//  Flamora app
//
//  全局颜色系统 - 所有页面统一使用 AppColors
//

import SwiftUI

struct AppColors {
    // MARK: - Brand
    static let brandPrimary     = Color(hex: "#FF6B47")
    static let brandSecondary   = Color(hex: "#FF8A6B")

    // MARK: - Gradient
    static let gradientFire: [Color] = [
        Color(hex: "#A78BFA"),
        Color(hex: "#FCA5A5"),
        Color(hex: "#FCD34D")
    ]
    static let gradientStart    = Color(hex: "#A78BFA")
    static let gradientMiddle   = Color(hex: "#FCA5A5")
    static let gradientEnd      = Color(hex: "#FCD34D")

    // MARK: - Functional
    static let success          = Color(hex: "#10B981")
    static let successAlt       = Color(hex: "#34C759")   // system-green variant
    static let warning          = Color(hex: "#F59E0B")
    static let error            = Color(hex: "#EF4444")
    static let info             = Color(hex: "#3B82F6")

    // MARK: - Text
    static let textPrimary      = Color(hex: "#FFFFFF")
    static let textSecondary    = Color(hex: "#9CA3AF")
    static let textTertiary     = Color(hex: "#6B7280")
    static let textMuted        = Color(hex: "#4B5563")
    static let textInverse      = Color(hex: "#000000")

    // MARK: - Background (page-level)
    static let backgroundPrimary    = Color(hex: "#000000")
    static let backgroundSecondary  = Color(hex: "#0F1419")
    static let backgroundInput      = Color(hex: "#1E2530")

    // MARK: - Surface (card-level) — matches the dark card style in design
    static let surface              = Color(hex: "#121212")   // main card bg
    static let surfaceElevated      = Color(hex: "#1A1A1A")   // icon bg / nested element
    static let surfaceBorder        = Color(hex: "#222222")   // card 1-pt border
    static let surfaceHighlight     = Color(hex: "#1E1E1E")   // pressed / hover state
    static let surfaceInput         = Color(hex: "#2C2C2E")   // progress track / input

    // Legacy aliases kept for backward-compat
    static let backgroundCard       = Color(hex: "#121212")
    static let backgroundCardHover  = Color(hex: "#1E1E1E")
    static let borderDefault        = Color(hex: "#222222")
    static let borderLight          = Color(hex: "#2A2A2A")

    // MARK: - Progress Bar
    static let progressTrack        = Color(hex: "#2C2C2E")
    static let progressPurple       = Color(hex: "#A78BFA")
    static let progressBlue         = Color(hex: "#93C5FD")
    static let progressBlueBright   = Color(hex: "#3B82F6")
    static let progressOrange       = Color(hex: "#FF6B47")
    static let progressGreen        = Color(hex: "#34C759")

    // MARK: - Accent
    static let accentPurple         = Color(hex: "#A78BFA")
    static let accentPurpleLight    = Color(hex: "#C4B5FD")
    static let accentBlue           = Color(hex: "#93C5FD")
    static let accentBlueBright     = Color(hex: "#60A5FA")
    static let accentPink           = Color(hex: "#F9A8D4")
    static let accentAmber          = Color(hex: "#FCD34D")
    static let accentGreen          = Color(hex: "#34D399")

    // MARK: - Flame Toggle (blue-purple per reference design)
    static let gradientFlamePill: [Color] = [
        Color(hex: "#60A5FA"),
        Color(hex: "#818CF8")
    ]

    // MARK: - Daily Quote Card
    static let dailyQuoteBg        = Color(hex: "#1D3A28")
    static let dailyQuoteAccent    = Color(hex: "#4ADE80")

    // MARK: - Glass Surface
    static let glassBorder         = Color.white.opacity(0.10)
    static let glassBackground     = Color.black.opacity(0.68)
}

// MARK: - Gradient Wallpaper (Welcome / Onboarding 背景)

struct MyGradients {
    static let gradientFire: [Color] = [
        Color(hex: "#A78BFA"),    // 紫色
        Color(hex: "#FCA5A5"),    // 粉色
        Color(hex: "#FCD34D")     // 黄色
    ]
}

struct GradientWallpaperView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: MyGradients.gradientFire),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
