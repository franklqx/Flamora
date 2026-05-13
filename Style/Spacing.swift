//
//  Spacing.swift
//  Meridian
//
//  全局间距和圆角系统 - 所有页面统一使用
//

import SwiftUI

struct AppSpacing {
    /// Tab 胶囊内边距等极紧间距
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    static let cardPadding: CGFloat = 20
    static let cardGap: CGFloat = 16
    static let screenPadding: CGFloat = 16
    static let sectionGap: CGFloat = 24
    /// 与系统尺寸 tabbar 占位对齐（含 Home Indicator 区缓冲）
    static let tabBarReserve: CGFloat = 68
    /// 底部 Tab 条水平 inset（贴近 iOS 26 默认）
    static let tabBarHorizontalInset: CGFloat = 16
    /// 收拢态单圆按钮边长（系统圆钮 44pt）
    static let tabBarCollapsedCircle: CGFloat = 50
    /// 三键胶囊内单行可点区域高度（对齐 HTML 50px）
    static let tabBarButtonRowHeight: CGFloat = 50
    /// Tab 图标行占位高度（对齐 HTML 22px icon）
    static let tabBarIconRowHeight: CGFloat = 22

    /// Home hero / Journey 渐变区高度 — 308pt 对应 HTML min-height: 308px（MainTabView 动态分区时的回退）
    static let heroFullHeight: CGFloat = 308

    /// Home 主列：渐变区收矮，主信息在 draggable sheet（与 Home roadmap + FIRE 进度合一）
    static let homeHeroRegionFraction: CGFloat = 0.22
    /// 白底 sheet 占可用高度比例（过高会在 Roadmap 等短内容下露出大块同色壳）
    static let homeSheetRegionFraction: CGFloat = 0.74
    /// 白底 sheet 上叠入 hero 的位移（HTML margin-top: -76px）
    static let homeSheetTopOverlap: CGFloat = 76

    /// Home 静止时：大气渐变占满 hero 区高度（对齐 `home-rebuild-glass-prototype.html` `.hero-layer` min-height + `background-size: 100% 100%`，不再做 22% 垂直压缩）
    static let homeHeroGradientCollapsedFraction: CGFloat = 1.0

    /// HTML `.cash-hero-copy` / `.invest-hero-copy` 大标题相对 hero 内容区顶部的间距
    static let heroTabTitleTopOffset: CGFloat = 22

    /// Home / Cash / Invest 三 Tab 白底 sheet 内首块主卡统一最小高度（对齐原型里 roadmap / cash-stage / invest-stage 视觉块一致）
    static let homeSheetPrimaryCardMinHeight: CGFloat = 400

    /// Sandbox HTML 柱状图单条宽度（Capsule）
    static let simulatorBarWidth: CGFloat = 5

    /// Top spacer height below the custom nav bar (clears the BudgetSetup nav bar)
    static let navBarTopSpace: CGFloat = 60
    /// Standard row-level horizontal/vertical item spacing (14pt)
    static let rowItem: CGFloat = 14
    /// Settings section label gap (10pt)
    static let sectionLabelGap: CGFloat = 10
}

struct AppRadius {
    /// 紧凑圆角（badge、小 pill）
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    /// 旧卡片圆角（connected 视图保留，新视图用 glassCard）
    static let card: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let button: CGFloat = 28
    static let full: CGFloat = 9999

    // ─── 新设计系统（home-rebuild-glass-prototype）────────────
    /// 主白色玻璃卡片 — 28pt（Cash Flow / Investment / Home cards）
    static let glassCard: CGFloat = 28
    /// 卡片内嵌二级 block — 20pt（budget/metric 小面板）
    static let glassBlock: CGFloat = 20
    /// Hero 区底部裁切弧 — 22pt
    static let heroBottom: CGFloat = 22
    /// Phone outer shell — 52pt（模拟器外壳）
    static let phoneShell: CGFloat = 52
    /// 中等面板 — 24pt（hero 行、tab 指示器等）
    static let glassPanel: CGFloat = 24
}
