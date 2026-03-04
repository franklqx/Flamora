//
//  Typography.swift
//  Fiamora app
//
//  Created by Frank Li 02/02/2026



import SwiftUI

struct AppTypography {
    // Font Sizes - 字号层级
    static let hero: CGFloat = 56
    static let display: CGFloat = 40
    static let h1: CGFloat = 32
    static let h2: CGFloat = 24
    static let h3: CGFloat = 20
    static let h4: CGFloat = 18
    static let body: CGFloat = 16
    static let bodySmall: CGFloat = 14
    static let caption: CGFloat = 12
    static let label: CGFloat = 10

    // Onboarding-specific sizes
    static let obSlideTitle: CGFloat = 36   // 欢迎轮播大标题
    static let obQuestion: CGFloat = 28     // 问卷页标题（大）
    static let obDisplay: CGFloat = 48      // 数字展示（滑块值）
    static let obStepLabel: CGFloat = 11    // STEP N OF N 标签
}

// MARK: - Font Extension
extension Font {
    // Hero Styles
    static var hero: Font {
        .system(size: AppTypography.hero, weight: .black)
    }

    static var display: Font {
        .system(size: AppTypography.display, weight: .bold)
    }

    // Heading Styles
    static var h1: Font {
        .system(size: AppTypography.h1, weight: .bold)
    }

    static var h2: Font {
        .system(size: AppTypography.h2, weight: .bold)
    }

    static var h3: Font {
        .system(size: AppTypography.h3, weight: .semibold)
    }

    static var h4: Font {
        .system(size: AppTypography.h4, weight: .semibold)
    }

    // Body Styles
    static var bodyRegular: Font {
        .system(size: AppTypography.body, weight: .regular)
    }

    static var bodySmall: Font {
        .system(size: AppTypography.bodySmall, weight: .regular)
    }

    static var caption: Font {
        .system(size: AppTypography.caption, weight: .regular)
    }

    static var label: Font {
        .system(size: AppTypography.label, weight: .semibold)
    }

    // MARK: - Onboarding Semantic Fonts
    /// 欢迎轮播幻灯片大标题 — serif 设计呈现编辑感
    static var obSlideTitle: Font {
        .system(size: AppTypography.obSlideTitle, weight: .semibold, design: .serif)
    }

    /// 问卷页主问题标题
    static var obQuestion: Font {
        .system(size: AppTypography.obQuestion, weight: .bold)
    }

    /// 数字展示（收入/支出/净资产滑块大数字）
    static var obDisplay: Font {
        .system(size: AppTypography.obDisplay, weight: .bold, design: .default)
    }

    /// 进度步骤标签（STEP N OF N / FINANCIAL SNAPSHOT）
    static var obStepLabel: Font {
        .system(size: AppTypography.obStepLabel, weight: .bold)
    }
}
