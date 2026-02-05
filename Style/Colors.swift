//
//  Colors.swift
//  Fiamora app
//
//  Created by Frank Li 02/02/2026
//

import SwiftUI

struct AppColors {
    // Brand Colors - 品牌主色
    static let brandPrimary = Color(hex: "#FF6B47")
    static let brandSecondary = Color(hex: "#FF8A6B")
    
    // Gradient - 品牌渐变
    static let gradientFire: [Color] = [
        Color(hex: "#A78BFA"),
        Color(hex: "#FCA5A5"),
        Color(hex: "#FCD34D")
    ]
    
    static let gradientStart = Color(hex: "#A78BFA")
    static let gradientMiddle = Color(hex: "#FCA5A5")
    static let gradientEnd = Color(hex: "#FCD34D")
    
    // Functional Colors - 功能色
    static let success = Color(hex: "#10B981")
    static let warning = Color(hex: "#F59E0B")
    static let error = Color(hex: "#EF4444")
    static let info = Color(hex: "#3B82F6")
    
    // Text Colors - 文字色
    static let textPrimary = Color(hex: "#FFFFFF")
    static let textSecondary = Color(hex: "#9CA3AF")
    static let textTertiary = Color(hex: "#6B7280")
    static let textInverse = Color(hex: "#000000")
    
    // Background Colors - 背景色
    static let backgroundPrimary = Color(hex: "#000000")
    static let backgroundSecondary = Color(hex: "#0F1419")
    static let backgroundCard = Color(hex: "#1A1F26")
    static let backgroundCardHover = Color(hex: "#242B34")
    static let backgroundInput = Color(hex: "#1E2530")
    
    // Border Colors - 边框色
    static let borderDefault = Color(hex: "#2D3748")
    static let borderLight = Color(hex: "#374151")
    
    // Progress Bar Colors - 进度条色
    static let progressTrack = Color(hex: "#2D3748")
    static let progressPurple = Color(hex: "#A78BFA")
    static let progressBlue = Color(hex: "#3B82F6")
    static let progressOrange = Color(hex: "#FF6B47")
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
