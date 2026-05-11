//
//  HomeJourneyProgressStrip.swift
//  Flamora app
//
//  Segmented hero track + copy (embedded on brand gradient Hero, not a separate card).
//

import SwiftUI

// MARK: - Segment mapping (12 segments, design reference)

enum HomeJourneyProgressMapping {
    static let totalSegments = 12

    /// 0..1 progress fraction. Once the user has a plan (hero loaded), this is
    /// portfolio-toward-FIRE. Before that, it follows the setup stage so the
    /// strip animates as the user advances through onboarding.
    static func progressFraction(
        for stage: HomeSetupStage,
        hero: HomeHeroModel?,
        portfolioTotal: Double? = nil
    ) -> Double {
        if hero != nil {
            return activeProgress(hero: hero, portfolioTotal: portfolioTotal)
        }
        switch stage {
        case .noGoal, .goalSet:    return 3.0  / Double(totalSegments)
        case .accountsLinked:      return 5.0  / Double(totalSegments)
        case .snapshotPending:     return 7.0  / Double(totalSegments)
        case .planPending:         return 9.0  / Double(totalSegments)
        case .active:              return 12.0 / Double(totalSegments)
        }
    }

    /// 0..1 portfolio progress toward FIRE. Returns 0 when inputs are missing.
    static func activeProgress(hero: HomeHeroModel?, portfolioTotal: Double?) -> Double {
        guard let hero, hero.fireNumber > 0 else { return 0 }
        let portfolio = portfolioTotal ?? hero.startingPortfolioBalance ?? 0
        return min(max(portfolio / hero.fireNumber, 0), 1)
    }

    /// Show the % readout once a plan exists. Pre-plan we keep the copy clean
    /// so users aren't seeing fake-precision percentages.
    static func trailingPercentText(
        stage: HomeSetupStage,
        hero: HomeHeroModel?,
        portfolioTotal: Double? = nil
    ) -> String? {
        guard hero != nil else { return nil }
        let pct = activeProgress(hero: hero, portfolioTotal: portfolioTotal) * 100
        if pct < 1 { return String(format: "%.1f%%", pct) }
        return "\(Int(pct.rounded()))%"
    }
}

// MARK: - View (embedded in Hero gradient — no card chrome)

struct HomeJourneyProgressStrip: View {
    let title: String
    let subtitle: String
    let totalSegments: Int
    /// 0..1 progress fraction. The in-progress segment is partially filled to
    /// reflect the remainder (e.g. 0.17 fills the first segment 17%).
    let progressFraction: Double
    let footerLabel: String
    let trailingPercentText: String?

    /// When the user has an active plan we render a richer layout: DAY counter,
    /// current portfolio amount on the left, FIRE target on the right, and a
    /// Freedom Date stamp in the bottom-right. All four are optional — missing
    /// values fall back to the setup layout (subtitle row + percent).
    let dayCount: Int?
    let startAmountText: String?
    let targetAmountText: String?
    let freedomDateText: String?

    init(
        title: String = "YOUR FIRE JOURNEY",
        subtitle: String = "Finish the set up to track your progress.",
        totalSegments: Int = HomeJourneyProgressMapping.totalSegments,
        progressFraction: Double,
        footerLabel: String = "FREEDOM DATE",
        trailingPercentText: String? = nil,
        dayCount: Int? = nil,
        startAmountText: String? = nil,
        targetAmountText: String? = nil,
        freedomDateText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.totalSegments = totalSegments
        self.progressFraction = min(max(progressFraction, 0), 1)
        self.footerLabel = footerLabel
        self.trailingPercentText = trailingPercentText
        self.dayCount = dayCount
        self.startAmountText = startAmountText
        self.targetAmountText = targetAmountText
        self.freedomDateText = freedomDateText
    }

    private var isActiveLayout: Bool {
        startAmountText != nil || targetAmountText != nil || dayCount != nil
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isAX: Bool { dynamicTypeSize.isAccessibilitySize }

    /// 单段填充比例（0..1）。已过的段=1，未到的段=0，正在进行的那一段=部分填充。
    private func segmentFill(at index: Int) -> Double {
        let segmentSize = 1.0 / Double(totalSegments)
        let segmentStart = Double(index) * segmentSize
        if progressFraction <= segmentStart { return 0 }
        if progressFraction >= segmentStart + segmentSize { return 1 }
        return (progressFraction - segmentStart) / segmentSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Kicker row: "YOUR FIRE JOURNEY" 左 + "DAY 9 · 9%" 右（layout X）
            // 大字号下竖排，避免右侧 kicker 被压缩或溢出。
            kickerRow
                .padding(.bottom, AppSpacing.sm)

            if !isActiveLayout {
                Text(subtitle)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.heroTextFaint)
                    .lineSpacing(3)
                    .padding(.bottom, AppSpacing.md)
            }

            // 进度条
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(0..<totalSegments, id: \.self) { index in
                        FillableSegment(fillFraction: segmentFill(at: index))
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("FIRE progress")
                .accessibilityValue("\(Int(progressFraction * 100)) percent")

                if isActiveLayout {
                    amountRow
                    footerRow
                } else {
                    preplanFooterRow
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Subviews (kicker / amount / footer)
    // 在 accessibility sizes（AX1+）下从横排切换到竖排，避免文本截断或溢出。

    @ViewBuilder
    private var kickerRow: some View {
        let titleText = Text(title)
            .font(.inlineFigureBold)
            .foregroundStyle(AppColors.heroTextPrimary)
            .tracking(AppTypography.Tracking.miniUppercase)

        let kickerText: Text? = kickerRightText.map { kicker in
            Text(kicker)
                .font(.smallLabel)
                .foregroundStyle(AppColors.heroTextPrimary)
                .tracking(AppTypography.Tracking.miniUppercase)
        }

        if isAX {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                titleText
                if let kickerText { kickerText }
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                titleText.lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: AppSpacing.sm)
                if let kickerText { kickerText.lineLimit(1) }
            }
        }
    }

    @ViewBuilder
    private var amountRow: some View {
        let start = startAmountText.map {
            Text($0)
                .font(.footnoteBold)
                .foregroundStyle(AppColors.heroTextPrimary)
        }
        let target = targetAmountText.map {
            Text($0)
                .font(.footnoteBold)
                .foregroundStyle(AppColors.heroTextPrimary)
        }

        if isAX {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if let start { start }
                if let target { target }
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                if let start { start.lineLimit(1).minimumScaleFactor(0.7) }
                Spacer(minLength: AppSpacing.xs)
                if let target { target.lineLimit(1).minimumScaleFactor(0.7) }
            }
        }
    }

    @ViewBuilder
    private var footerRow: some View {
        let label = Text(footerLabel)
            .font(.label)
            .foregroundStyle(AppColors.heroTextHint)
            .tracking(AppTypography.Tracking.miniUppercase)
            .textCase(.uppercase)
        let date = freedomDateText.map {
            Text($0)
                .font(.footnoteSemibold)
                .foregroundStyle(AppColors.heroTextPrimary)
        }

        if isAX {
            VStack(alignment: .leading, spacing: 2) {
                label
                if let date { date }
            }
        } else {
            HStack(spacing: AppSpacing.xs) {
                Spacer(minLength: 0)
                label.lineLimit(1)
                if let date { date.lineLimit(1).minimumScaleFactor(0.8) }
            }
        }
    }

    @ViewBuilder
    private var preplanFooterRow: some View {
        let percent = trailingPercentText.map {
            Text($0)
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.heroTextPrimary)
        }
        let label = Text(footerLabel)
            .font(.label)
            .foregroundStyle(AppColors.heroTextHint)
            .tracking(AppTypography.Tracking.miniUppercase)
            .textCase(.uppercase)

        if isAX {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if let percent { percent }
                label
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                if let percent { percent.lineLimit(1).minimumScaleFactor(0.6) }
                Spacer(minLength: 0)
                label.lineLimit(1)
            }
        }
    }

    /// Active 时把 DAY 与百分比合并到右上角："DAY 9 · 9%"。
    /// 其中一个缺失就只显示另一个；都没有则不渲染右上角文本。
    private var kickerRightText: String? {
        let dayPart: String? = dayCount.map { "DAY \($0)" }
        let pctPart: String? = isActiveLayout ? trailingPercentText : nil
        switch (dayPart, pctPart) {
        case let (d?, p?): return "\(d) · \(p)"
        case let (d?, nil): return d
        case let (nil, p?): return p
        case (nil, nil):    return nil
        }
    }
}

// MARK: - Fillable segment (per-segment partial fill, brand blue-purple)

/// 单段进度 capsule。
/// - 底轨：`heroTrack`（淡白色）
/// - 已填充部分：`gradientShellAccent`（onboarding CTA 蓝紫渐变）从左向右铺
/// - `fillFraction = 0..1`：0 全空、1 全满、中间值=该段正在被填充
private struct FillableSegment: View {
    let fillFraction: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(fillFraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.heroTrack)

                if clamped > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: AppColors.gradientShellAccent,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(clamped))
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Factory (Hero layer only)

extension HomeJourneyProgressStrip {
    /// Progress copy + track laid on the brand gradient (no card background).
    /// In active mode, supply `portfolioTotal` (sum of investment accounts) so
    /// the strip can compute portfolio-toward-FIRE progress without referencing
    /// net worth. `daysSincePlanStart`, freedom date, and target amount are
    /// optional — provide them when the active plan + net worth data is loaded.
    static func heroEmbedded(
        stage: HomeSetupStage,
        homeHero: HomeHeroModel?,
        portfolioTotal: Double? = nil,
        daysSincePlanStart: Int? = nil,
        freedomDateText: String? = nil
    ) -> HomeJourneyProgressStrip {
        let progress = HomeJourneyProgressMapping.progressFraction(
            for: stage,
            hero: homeHero,
            portfolioTotal: portfolioTotal
        )
        let percent = HomeJourneyProgressMapping.trailingPercentText(
            stage: stage,
            hero: homeHero,
            portfolioTotal: portfolioTotal
        )

        // Active layout kicks in once a plan exists. Investment accounts can
        // still be missing — portfolioTotal then reads as $0 and progress 0%.
        let isActive = homeHero != nil
        let startText: String? = {
            guard isActive else { return nil }
            let portfolio = portfolioTotal ?? homeHero?.startingPortfolioBalance ?? 0
            return formatHeroAmount(portfolio)
        }()
        let targetText: String? = {
            guard isActive, let hero = homeHero else { return nil }
            return formatHeroAmount(hero.fireNumber)
        }()

        return HomeJourneyProgressStrip(
            progressFraction: progress,
            trailingPercentText: percent,
            dayCount: isActive ? daysSincePlanStart : nil,
            startAmountText: startText,
            targetAmountText: targetText,
            freedomDateText: isActive ? freedomDateText : nil
        )
    }

    private static func formatHeroAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview("Embedded on gradient") {
    ZStack(alignment: .topLeading) {
        LinearGradient(
            gradient: AppColors.heroBrandLinearGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        HomeJourneyProgressStrip.heroEmbedded(stage: .noGoal, homeHero: nil)
            .padding(.top, AppSpacing.heroTabTitleTopOffset)
    }
}
