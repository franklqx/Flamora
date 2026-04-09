//
//  Shadows.swift
//  Flamora app
//
//  Glass shadow system — ViewModifiers for multi-layer SwiftUI shadows.
//  Source: design-reference/home-rebuild-glass-prototype.html
//

import SwiftUI

// MARK: - Glass Card Shadow

/// Two-layer shadow for white glass cards on the light shell.
/// CSS reference:
///   0 18px 40px rgba(71, 55, 101, 0.12),
///   0 2px 8px rgba(71, 55, 101, 0.05)
struct GlassCardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color(hex: "#473765").opacity(0.12),
                radius: 20,
                x: 0,
                y: 18
            )
            .shadow(
                color: Color(hex: "#473765").opacity(0.05),
                radius: 4,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Sim Details Shadow

/// Shadow for the simulator details panel (dark glass).
/// CSS reference:
///   0 18px 36px rgba(9, 11, 28, 0.22),
///   inset 0 1px 0 rgba(255, 255, 255, 0.08)
struct SimDetailsShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color(hex: "#09091C").opacity(0.22),
                radius: 18,
                x: 0,
                y: 18
            )
    }
}

// MARK: - Tab Bar Shadow

/// Shadow for the floating glass tab bar.
/// CSS reference: 0 18px 40px rgba(17, 24, 39, 0.16)
struct TabBarShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: AppColors.tabBarShadow,
                radius: 20,
                x: 0,
                y: 18
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Multi-layer shadow for white glass cards on the light shell.
    func glassCardShadow() -> some View {
        modifier(GlassCardShadowModifier())
    }

    /// Shadow for the dark glass simulator details panel.
    func simDetailsShadow() -> some View {
        modifier(SimDetailsShadowModifier())
    }

    /// Shadow for the floating glass tab bar.
    func tabBarShadow() -> some View {
        modifier(TabBarShadowModifier())
    }
}
