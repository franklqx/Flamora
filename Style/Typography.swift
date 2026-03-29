//
//  Typography.swift
//  Flamora app
//
//  Created by Frank Li 02/02/2026
//
//  ╔══════════════════════════════════════════════════════════╗
//  ║  换字体：只改 appFont() 里的 design 参数，全 app 生效    ║
//  ║  改字号：只改 AppTypography 里的 size 常量               ║
//  ╚══════════════════════════════════════════════════════════╝

import SwiftUI
import UIKit

// MARK: - Size Scale

struct AppTypography {
    // 字号层级 — 改这里影响所有用到该常量的 token
    static let display:             CGFloat = 40
    static let h1:                  CGFloat = 32
    static let h2:                  CGFloat = 24
    static let h3:                  CGFloat = 20
    static let h4:                  CGFloat = 18
    static let body:                CGFloat = 16
    static let bodySmall:           CGFloat = 14
    static let caption:             CGFloat = 12
    static let label:               CGFloat = 10
    static let cardFigureSecondary: CGFloat = 15   // 卡片副数字

    enum Tracking {
        static let cardHeader:    CGFloat = 0.8    // 全大写卡片标题
        static let miniUppercase: CGFloat = 0.5    // 紧凑大写微标签
    }
}

// MARK: - Typeface Entry Point
//
// ✅ 换整个 app 的字体：只改这一个函数
// 当前：SF Pro（系统默认）
// 换 SF Rounded：.system(size: size, weight: weight, design: .rounded)
// 换自定义字体：Font(UIFont(name: "MyFont-Bold", size: size) ?? ...)

private extension Font {
    static func appFont(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Font Tokens

extension Font {

    // ── Headings ──────────────────────────────────────────────
    static var display:     Font { appFont(AppTypography.display, .bold) }
    static var h1:          Font { appFont(AppTypography.h1,      .bold) }
    static var h2:          Font { appFont(AppTypography.h2,      .bold) }
    static var h3:          Font { appFont(AppTypography.h3,      .semibold) }
    static var h4:          Font { appFont(AppTypography.h4,      .semibold) }
    static var portfolioHero: Font { appFont(34, .semibold) }

    // ── Body ──────────────────────────────────────────────────
    static var bodyRegular:       Font { appFont(AppTypography.body,      .regular) }
    static var bodySemibold:      Font { appFont(AppTypography.body,      .semibold) }
    static var bodySmall:         Font { appFont(AppTypography.bodySmall, .regular) }
    static var bodySmallSemibold: Font { appFont(AppTypography.bodySmall, .semibold) }

    // ── Labels ────────────────────────────────────────────────
    static var caption:    Font { appFont(AppTypography.caption, .regular) }
    static var smallLabel: Font { appFont(AppTypography.caption, .semibold) }   // 12 / semibold
    static var label:      Font { appFont(AppTypography.label,   .semibold) }   // 10 / semibold
    static var miniLabel:  Font { appFont(9,                     .semibold) }   // 9  / semibold

    // ── Footnote family (13pt) ────────────────────────────────
    static var footnoteRegular:  Font { appFont(13, .regular) }
    static var footnoteSemibold: Font { appFont(13, .semibold) }
    static var footnoteBold:     Font { appFont(13, .bold) }

    // ── Inline row text (14pt) ────────────────────────────────
    static var inlineLabel:     Font { appFont(AppTypography.bodySmall, .medium) }   // 14 / medium
    static var inlineFigureBold: Font { appFont(AppTypography.bodySmall, .bold) }    // 14 / bold

    // ── Supporting / secondary (15pt) ─────────────────────────
    static var supportingText:         Font { appFont(AppTypography.cardFigureSecondary, .regular) }
    static var figureSecondarySemibold: Font { appFont(AppTypography.cardFigureSecondary, .semibold) }
    static var cardFigureSecondary:     Font { appFont(AppTypography.cardFigureSecondary, .bold) }

    // ── Stat / field rows (17pt) ──────────────────────────────
    static var statRowSemibold: Font { appFont(17, .semibold) }
    static var fieldBodyMedium: Font { appFont(17, .medium) }

    // ── Card chrome ───────────────────────────────────────────
    /// All-caps card section title — pair with Tracking.cardHeader + textTertiary
    static var cardHeader:   Font { appFont(11, .bold) }
    /// Row meta / secondary annotation
    static var cardRowMeta:  Font { appFont(11, .medium) }
    /// Primary large number on cards (28pt)
    static var cardFigurePrimary: Font { appFont(28, .bold) }

    /// Segment / tab row — bold when selected
    static func segmentLabel(selected: Bool) -> Font {
        appFont(11, selected ? .bold : .semibold)
    }

    // ── Section & sheet titles ────────────────────────────────
    static var detailTitle: Font { appFont(22, .bold) }    // sheet sub-header
    static var detailSheetTitle: Font { appFont(AppTypography.h1, .bold) }  // large sheet header (= h1)

    // ── Special UI controls ───────────────────────────────────
    static var sheetPrimaryButton: Font { appFont(AppTypography.h4, .bold) }   // 18 / bold
    static var sheetCloseGlyph:    Font { appFont(28, .regular) }              // dismiss ×
    static var chromeIconMedium:   Font { appFont(AppTypography.h4, .medium) } // tab bar icon
    static var navChevron:         Font { appFont(26, .semibold) }             // full-screen back
    static var categoryRowIcon:    Font { appFont(21, .semibold) }             // list icon
    static var quoteBody:          Font { appFont(AppTypography.h3, .bold) }   // quote card body
    static var currencyHero:       Font { appFont(48, .bold) }                 // large currency display

    /// Micro month/bar tick (10pt)
    static func barMonthTick(selected: Bool) -> Font {
        appFont(AppTypography.label, selected ? .bold : .medium)
    }

    // ── Onboarding — intentionally NOT routed through appFont ─
    // These use a distinct serif/script typeface as part of the OB brand
    static var obQuestion: Font {
        Font(UIFont(name: "PlayfairDisplayRoman-SemiBold", size: 24)
             ?? UIFont.systemFont(ofSize: 24, weight: .semibold))
    }
}
