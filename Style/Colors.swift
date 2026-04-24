//
//  Colors.swift
//  Flamora app
//
//  全局颜色系统 - 所有页面统一使用 AppColors
//

import SwiftUI
import UIKit

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

    // MARK: - Origin Palette (unified data-viz & semantic palette on light shell)
    /// Positive / Stocks / Assets / up trend — Origin Emerald
    static let allocEmerald     = Color(hex: "#10B981")
    /// Warning / Crypto / Bonds / Credit — Origin Amber
    static let allocAmber       = Color(hex: "#F59E0B")
    /// Info / Cash / primary accent — Origin Indigo
    static let allocIndigo      = Color(hex: "#3B82F6")
    /// Negative / Loans / down trend / error — Origin Coral (softer than punchy red)
    static let allocCoral       = Color(hex: "#F97066")

    // MARK: - Functional (aliased to Origin palette — single source of truth)
    static let success          = allocEmerald
    static let successAlt       = Color(hex: "#34C759")   // system-green variant
    static let warning          = allocAmber
    static let error            = allocCoral
    static let info             = allocIndigo

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
    static let accentPurpleMid      = Color(hex: "#7C3AED")
    static let accentPurpleDeep     = Color(hex: "#6D28D9")
    static let accentPurpleFaint    = Color(hex: "#DDD6FE")
    static let accentBlue           = Color(hex: "#93C5FD")
    static let accentBlueBright     = Color(hex: "#60A5FA")
    static let accentPink           = Color(hex: "#F9A8D4")
    static let accentAmber          = Color(hex: "#FCD34D")
    static let accentGreen          = Color(hex: "#34D399")
    /// 负向涨跌等（与 `error` 同色）
    static let accentRed            = AppColors.error
    static let accentGreenDeep      = Color(hex: "#059669")
    static let accentGreenLight     = Color(hex: "#6EE7B7")
    static let accentGreenFaint     = Color(hex: "#A7F3D0")

    // MARK: - Chart Series Colors（深色背景专用图表色）
    static let chartBlue    = Color(hex: "#2563EB")   // 深蓝 — Stocks / Needs
    static let chartAmber   = Color(hex: "#D97706")   // 深琥珀 — Crypto / Bonds
    /// Wants 分类（与 chartAmber 同色，语义别名）
    static let chartGold    = chartAmber
    static let chartRose    = Color(hex: "#DB2777")   // 深玫红 — Other
    static let chartSteelBlue = Color(hex: "#6699CC") // Steel Blue — Stocks
    static let chartSageGreen = Color(hex: "#71963C") // Sage Green — Cash
    static let chartYellow    = Color(hex: "#F2D349") // Yellow — Crypto
    static let chartCoral     = Color(hex: "#D99468") // Coral — Other

    // MARK: - Flame Toggle (blue-purple per reference design)
    static let gradientFlamePill: [Color] = [
        Color(hex: "#60A5FA"),
        Color(hex: "#818CF8")
    ]

    // MARK: - Light Shell Accent Gradient (blue → indigo-purple, for accents on light-shell backgrounds)
    static let gradientShellAccent: [Color] = [
        Color(hex: "#60A5FA"),   // sky blue
        Color(hex: "#818CF8"),   // indigo-purple
    ]

    // MARK: - Daily Quote Card
    static let dailyQuoteBg        = Color(hex: "#1D3A28")
    static let dailyQuoteAccent    = Color(hex: "#4ADE80")

    // MARK: - Glass Surface (legacy dark-mode glass — kept for connected views)
    static let glassBorder         = Color.white.opacity(0.10)
    static let glassBackground     = Color.black.opacity(0.68)

    // MARK: - Card Depth
    static let cardShadow          = Color.black.opacity(0.40)
    static let cardTopHighlight    = Color.white.opacity(0.06)

    // MARK: - Glass Pill (time range selector)
    static let glassPillFill       = Color.white.opacity(0.10)
    static let glassPillStroke     = Color.white.opacity(0.15)

    // ════════════════════════════════════════════════════════
    // MARK: - NEW DESIGN SYSTEM (Light Shell + Dark Hero)
    // 对应 design-reference/home-rebuild-glass-prototype.html
    // ════════════════════════════════════════════════════════

    // MARK: Ink (dark text on light backgrounds)
    /// Primary text on light shell — #111827
    static let inkPrimary          = Color(hex: "#111827")
    /// Secondary text — 66% ink
    static let inkSoft             = Color(hex: "#111827").opacity(0.66)
    /// Tertiary text — 42% ink
    static let inkFaint            = Color(hex: "#111827").opacity(0.42)
    /// Meta / kicker labels — 34% ink
    static let inkMeta             = Color(hex: "#111827").opacity(0.34)
    /// Chip label — 62% ink
    static let inkChip             = Color(hex: "#111827").opacity(0.62)
    /// 1pt border on light backgrounds — 8% ink
    static let inkBorder           = Color(hex: "#111827").opacity(0.08)
    /// Subtle divider line — 7% ink
    static let inkDivider          = Color(hex: "#111827").opacity(0.07)
    /// Dashed mid-chart line — 12% ink
    static let inkDash             = Color(hex: "#111827").opacity(0.12)
    /// Progress bar fill / bar chart fill — dark ink gradient
    static let inkBarFill1         = Color(hex: "#111827").opacity(0.88)
    static let inkBarFill2         = Color(hex: "#111827").opacity(0.72)
    /// Progress track on light bg — 10% ink
    static let inkTrack            = Color(hex: "#111827").opacity(0.10)

    // MARK: Shell Background (below hero)
    /// Shell background top — #F5F6F8
    static let shellBg1            = Color(hex: "#F5F6F8")
    /// Shell background bottom — #F5F6F8
    static let shellBg2            = Color(hex: "#F5F6F8")

    // MARK: Hero Gradient (dark atmospheric, top of each tab)
    // Base linear layer matches `design-reference/home-rebuild-glass-prototype.html` `--brand-purple-surface` stops (non-uniform, not equal fifths).
    static let heroGradient: [Color] = [
        Color(hex: "#15162a"),   // dark navy-violet (top)
        Color(hex: "#242b63"),   // deep blue-purple
        Color(hex: "#5a6fe0"),   // blue-purple mid
        Color(hex: "#d8dbff"),   // pale lavender
        Color(hex: "#f7f3ff"),   // near-white purple tint (bottom)
    ]

    /// Home hero — same colors as `heroGradient` with CSS locations 0 / 18% / 42% / 68% / 100%
    /// 末端不抬到近白，避免与白 sheet 叠出「壳白」挤在屏内；接壳浅色由 `shellUnderlay`（sheet 背后层）承担。
    static var heroBrandLinearGradient: Gradient {
        Gradient(stops: [
            .init(color: Color(hex: "#15162a"), location: 0),
            .init(color: Color(hex: "#242b63"), location: 0.28),
            .init(color: Color(hex: "#4f65dc"), location: 0.80),
            .init(color: Color(hex: "#6b7fd8"), location: 0.92),
            .init(color: Color(hex: "#7a90e8"), location: 1),
        ])
    }

    /// Welcome-only gradient — deep brand at top, bleeds to `shellBg1` at bottom
    /// so切到 Sign-in (light-shell) 时底部像素级连续，无撕裂感。
    static var heroWelcomeGradient: Gradient {
        Gradient(stops: [
            .init(color: Color(hex: "#15162a"), location: 0.00),
            .init(color: Color(hex: "#242b63"), location: 0.22),
            .init(color: Color(hex: "#4f65dc"), location: 0.48),
            .init(color: Color(hex: "#8ea4f0"), location: 0.70),
            .init(color: Color(hex: "#d5defa"), location: 0.86),
            .init(color: Color(hex: "#f7f8fb"), location: 1.00),
        ])
    }
    /// Radial glow 1 — purple haze, top-left of hero
    static let heroGlowPurple1     = Color(hex: "#c4b5fd").opacity(0.22)
    /// Radial glow 2 — purple haze, top-right of hero
    static let heroGlowPurple2     = Color(hex: "#a78bfa").opacity(0.26)
    /// Radial glow 3 — pink warmth, center-lower of hero
    static let heroGlowPink        = Color(hex: "#fca5a5").opacity(0.10)

    // MARK: Glass Card (white glass on light shell)
    /// Card primary fill — rgba(255,255,255,0.84)
    static let glassCardBg         = Color.white.opacity(0.84)
    /// Card secondary fill layer — rgba(250,246,251,0.74)
    static let glassCardBg2        = Color(hex: "#faf6fb").opacity(0.74)
    /// Card stroke — rgba(255,255,255,0.56)
    static let glassCardBorder     = Color.white.opacity(0.56)
    /// Card inner highlight (inset top edge) — rgba(255,255,255,0.72)
    static let glassCardHighlight  = Color.white.opacity(0.72)
    /// Card shadow tint — rgba(71,55,101,0.12)
    static let glassCardShadow     = Color(hex: "#473765").opacity(0.12)

    // MARK: Glass Block (nested secondary panel within card)
    /// Block fill — rgba(255,255,255,0.32)
    static let glassBlockBg        = Color.white.opacity(0.32)
    /// Block stroke — rgba(255,255,255,0.34)
    static let glassBlockBorder    = Color.white.opacity(0.34)

    // MARK: Hero Surface Text (text on top of dark hero)
    /// Primary white on hero (near-full opacity)
    static let heroTextPrimary     = Color.white.opacity(0.98)
    /// Soft white on hero — secondary
    static let heroTextSoft        = Color.white.opacity(0.94)
    /// Dim white on hero — tertiary
    static let heroTextFaint       = Color.white.opacity(0.58)
    /// Ultra-dim — placeholder / hint on hero
    static let heroTextHint        = Color.white.opacity(0.36)
    /// Hero progress track
    static let heroTrack           = Color.white.opacity(0.16)
    /// Hero track fill (active segment)
    static let heroTrackFill       = Color.white.opacity(0.50)

    // MARK: Investment Hero Gradient (blue-cold variant, distinct from Home heroGradient)
    // Usage: prefer `investBrandLinearGradient` for full-bleed hero (matches HTML stop positions).
    static let investHeroGradient: [Color] = [
        Color(hex: "#13152a"),   // deep navy (top)
        Color(hex: "#20275f"),   // dark indigo
        Color(hex: "#556add"),   // blue-indigo mid
        Color(hex: "#d9dcff"),   // pale blue-lavender
        Color(hex: "#f8f4ff"),   // near-white cool tint (bottom)
    ]

    /// Investment tab — same stop layout as `design-reference/home-rebuild-glass-prototype.html` `.invest-view`
    /// 末端不抬到近白，接壳由 `shellUnderlay`（sheet 后）承担。
    static var investBrandLinearGradient: Gradient {
        Gradient(stops: [
            .init(color: Color(hex: "#13152a"), location: 0),
            .init(color: Color(hex: "#20275f"), location: 0.20),
            .init(color: Color(hex: "#4b61d8"), location: 0.50),
            .init(color: Color(hex: "#7c92e8"), location: 0.88),
            .init(color: Color(hex: "#8aa0ef"), location: 1),
        ])
    }

    /// Investment hero radial 2 — HTML `rgba(167, 139, 250, 0.28)` (Home/Cash use `heroGlowPurple2` at 0.26)
    static let investHeroGlowPurple2 = Color(hex: "#a78bfa").opacity(0.28)

    // MARK: Tab Bar (glass floating tab bar on light shell)
    /// Tab bar primary fill — kept for fallback surfaces
    static let tabBarFill          = Color.white.opacity(0.52)
    /// Capsule/circle glass fill (light background, matches HTML rgba(255,255,255,.68))
    static let tabBarGlassBarTint  = Color.white.opacity(0.68)
    /// Selected pill — darker than capsule (inverted), matches HTML rgba(0,0,0,.07)
    static let tabBarGlassSelectedTint = Color.black.opacity(0.07)
    /// Collapsed circle fill
    static let tabBarCollapsedGlassTint = Color.white.opacity(0.68)
    /// Capsule/circle border
    static let tabBarBorder        = Color.black.opacity(0.08)
    /// Inner top highlight
    static let tabBarHighlight     = Color.white.opacity(0.90)
    /// Drop shadow tint
    static let tabBarShadow        = Color.black.opacity(0.10)
    /// Active tab icon/label — pure black
    static let tabBarActiveItem    = Color.black.opacity(0.88)
    /// Inactive tab icon/label — same black tone; selected state is expressed by the pill.
    static let tabBarInactiveLabel = tabBarActiveItem

    // MARK: Simulator trend chart (integrated on atmospheric gradient)
    /// Vertical bar fill — soft white capsules on gradient
    static let simulatorTrendBar     = Color.white.opacity(0.42)
    /// Earlier / de-emphasized bars in the trend strip
    static let simulatorTrendBarSoft = Color.white.opacity(0.28)
    /// Floating amount + age callout — glass pill (HTML `.bar-callout`: blur + rgba white)
    static let simulatorCalloutBubbleFill = Color.white.opacity(0.08)
    static let simulatorCalloutBubbleBorder = Color.white.opacity(0.08)
    /// Callout label — rgba(255,255,255,0.84)
    static let simulatorCalloutForeground = Color.white.opacity(0.84)

    // MARK: Simulator Details Panel (dark glass panel inside simulator)
    /// Sim details panel bg gradient top — rgba(33,37,78,0.94)
    static let simDetailsBg1       = Color(hex: "#21254E").opacity(0.94)
    /// Sim details panel bg gradient bottom — rgba(25,28,61,0.96)
    static let simDetailsBg2       = Color(hex: "#191C3D").opacity(0.96)
    /// Sim details panel border — rgba(255,255,255,0.12)
    static let simDetailsBorder    = Color.white.opacity(0.12)

    // MARK: CTA Button (black on light shell)
    /// Black button background for light-shell CTAs
    static let ctaBlack            = Color(hex: "#111827")
    /// White label on black CTA
    static let ctaWhite            = Color.white

    // MARK: - White / black overlays
    // 9-tier canonical scale — prefer these over raw Color.white/black.opacity
    //
    //  overlayWhiteWash          0.04  — barely-there tracks, nested fills
    //  cardTopHighlight          0.06  — hairline separators, card top edge  (alias kept below)
    //  overlayWhiteStroke        0.08  — 1pt borders, subtle dividers
    //  overlayWhiteMid           0.12  — glass pill backgrounds, soft fills
    //  glassPillStroke           0.15  — glass pill stroke              (alias kept below)
    //  overlayWhiteHigh          0.18  — glass card sheen, gradient stop
    //  overlayWhiteEmphasisStroke 0.35 — prominent chrome stroke
    //  overlayWhiteForegroundMuted 0.45 — muted foreground labels on glass
    //  overlayWhiteOnGlass       0.75  — high-contrast text on glass

    /// 0.04 — barely-there track / nested fill
    static let overlayWhiteWash           = Color.white.opacity(0.04)
    /// 0.08 — hairline 1pt borders, dividers
    static let overlayWhiteStroke         = Color.white.opacity(0.08)
    /// 0.12 — glass pill background, soft fills
    static let overlayWhiteMid            = Color.white.opacity(0.12)
    /// 0.18 — strong glass sheen / gradient stop
    static let overlayWhiteHigh           = Color.white.opacity(0.18)
    /// 0.35 — prominent chrome stroke / emphasis border
    static let overlayWhiteEmphasisStroke = Color.white.opacity(0.35)
    /// 0.40 — page-indicator / secondary dimmed control
    static let overlayWhiteAt40           = Color.white.opacity(0.4)
    /// 0.45 — muted white foreground (secondary copy on dark glass)
    static let overlayWhiteForegroundMuted = Color.white.opacity(0.45)
    /// 0.30 — tertiary white foreground
    static let overlayWhiteForegroundSoft = Color.white.opacity(0.30)
    /// 0.50 — controls on photo / bright backgrounds
    static let overlayWhiteOnPhoto        = Color.white.opacity(0.50)
    /// 0.60 — secondary labels on busy backgrounds (charts, roadmap)
    static let overlayWhiteAt60           = Color.white.opacity(0.6)
    /// 0.25 — dimmer tertiary label
    static let overlayWhiteAt25           = Color.white.opacity(0.25)
    /// 0.75 — high-contrast label on translucent surfaces
    static let overlayWhiteOnGlass        = Color.white.opacity(0.75)

    /// Soft black veil (gradients, quote card)
    static let overlayBlackSoft           = Color.black.opacity(0.15)
    /// Deeper black gradient stop (quote card, scrims)
    static let overlayBlackMid            = Color.black.opacity(0.35)

    // MARK: - Income Source Color Scales
    static let activeIncomeScale: [Color] = [
        accentGreenDeep,
        success,
        accentGreen,
        accentGreenLight,
        accentGreenFaint,
    ]
    static let passiveIncomeScale: [Color] = [
        accentPurpleDeep,
        accentPurpleMid,
        accentPurple,
        accentPurpleLight,
        accentPurpleFaint,
    ]

    /// 多收入来源分段（圆环、列表、柱状图同一索引同色）；不含默认收入紫，绿为主、再蓝/琥珀等便于区分。
    static let incomeSegmentPalette: [Color] = [
        accentGreenDeep,
        chartBlue,
        chartAmber,
        accentGreen,
        chartSteelBlue,
        chartYellow,
        chartCoral,
    ]

    /// UIKit 控件（如 `UISlider`）thumb tint；Onboarding 浅色底上需可见，与 `gradientShellAccent` 蓝一致。
    static let uiSliderThumbTint: UIColor = UIColor(Color(hex: "#60A5FA"))

    // MARK: - Budget Setup
    /// Gold accent used for spinners, "Recommended" badge, and difficulty indicators
    static let budgetGold           = Color(hex: "#F5C842")
    /// Pink accent used in spinner inner ring and gradient pair with budgetGold
    static let budgetPink           = Color(hex: "#E88BC4")
    /// Teal/mint used for Wants arc, "done" checkmark circle, and Steady difficulty color
    static let budgetTeal           = Color(hex: "#5DDEC0")
    /// Purple used for Needs arc and ring segment in confirm view
    static let budgetPurple         = Color(hex: "#C084FC")
    /// Savings tip card green label
    static let budgetGreenLabel     = Color(hex: "#5EEAA0")
    /// Savings tip card — dark gradient start (green)
    static let budgetGreenDarkStart = Color(red: 34/255, green: 120/255, blue: 80/255)
    /// Savings tip card — dark gradient end (deep green)
    static let budgetGreenDarkEnd   = Color(red: 22/255, green: 80/255, blue: 55/255)
    /// Savings tip card stroke
    static let budgetGreenStroke    = Color(red: 52/255, green: 180/255, blue: 100/255)
    /// Custom zone: danger gradient start
    static let budgetDangerStart    = Color(hex: "#7F1D1D")
    /// Custom zone: danger gradient end
    static let budgetDangerEnd      = Color(hex: "#450A0A")
    /// Custom zone: warning gradient start
    static let budgetWarningStart   = Color(hex: "#78350F")
    /// Custom zone: warning gradient end
    static let budgetWarningEnd     = Color(hex: "#431407")
    /// Custom zone: ambitious gradient start
    static let budgetAmbitiousStart = Color(hex: "#1E3A5F")
    /// Custom zone: ambitious gradient end
    static let budgetAmbitiousEnd   = Color(hex: "#0F2236")
    /// Accelerate difficulty color
    static let budgetOrange         = Color(hex: "#F59E42")

    // MARK: - Cashflow Budget (aligned to Origin palette)
    /// Needs 主色 — Origin Indigo
    static let budgetNeedsBlue      = allocIndigo
    /// Needs 浅色底（用于浅色卡中的标签/子块）
    static let budgetNeedsBlueTint  = Color(hex: "#EAF0FF")
    /// Wants 主色 — Origin Amber
    static let budgetWantsPurple    = allocAmber
    /// Wants 浅色底（用于浅色卡中的标签/子块）— 琥珀浅底
    static let budgetWantsPurpleTint = Color(hex: "#FEF3C7")
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
