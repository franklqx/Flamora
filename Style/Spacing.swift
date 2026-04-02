//
//  Spacing.swift
//  Flamora app
//
//  全局间距和圆角系统 - 所有页面统一使用
//

import SwiftUI

struct AppSpacing {
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
    static let tabBarReserve: CGFloat = 84

    /// Top spacer height below the custom nav bar (clears the BudgetSetup nav bar)
    static let navBarTopSpace: CGFloat = 60
    /// Standard row-level horizontal/vertical item spacing (14pt)
    static let rowItem: CGFloat = 14
    /// Settings section label gap (10pt)
    static let sectionLabelGap: CGFloat = 10
}

struct AppRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    /// 卡片、里程碑格等（与 CLAUDE 示例一致）
    static let card: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let button: CGFloat = 28
    static let full: CGFloat = 9999
}
