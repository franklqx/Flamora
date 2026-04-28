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

    /// Per-segment fill fraction (0..1) so the in-progress segment can render
    /// a partial bar without rounding up.
    private func segmentFill(at index: Int) -> Double {
        let segmentSize = 1.0 / Double(totalSegments)
        let segmentStart = Double(index) * segmentSize
        if progressFraction <= segmentStart { return 0 }
        if progressFraction >= segmentStart + segmentSize { return 1 }
        return (progressFraction - segmentStart) / segmentSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.inlineFigureBold)
                    .foregroundStyle(AppColors.heroTextPrimary)
                    .tracking(AppTypography.Tracking.miniUppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: AppSpacing.sm)

                if let dayCount {
                    Text("DAY \(dayCount)")
                        .font(.smallLabel)
                        .foregroundStyle(AppColors.heroTextPrimary)
                        .tracking(AppTypography.Tracking.miniUppercase)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, AppSpacing.sm)

            if !isActiveLayout {
                Text(subtitle)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.heroTextFaint)
                    .lineSpacing(3)
                    .padding(.bottom, AppSpacing.md)
            }

            if isActiveLayout, let trailingPercentText {
                HStack {
                    Spacer(minLength: 0)
                    Text(trailingPercentText)
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.heroTextPrimary)
                }
                .padding(.bottom, 4)
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(0..<totalSegments, id: \.self) { index in
                        SegmentBar(fillFraction: segmentFill(at: index))
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("FIRE progress")
                .accessibilityValue("\(Int(progressFraction * 100)) percent")

                if isActiveLayout {
                    HStack(alignment: .firstTextBaseline) {
                        if let startAmountText {
                            Text(startAmountText)
                                .font(.footnoteBold)
                                .foregroundStyle(AppColors.heroTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer(minLength: AppSpacing.xs)
                        if let targetAmountText {
                            Text(targetAmountText)
                                .font(.footnoteBold)
                                .foregroundStyle(AppColors.heroTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }

                    HStack {
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(footerLabel)
                                .font(.label)
                                .foregroundStyle(AppColors.heroTextHint)
                                .tracking(AppTypography.Tracking.miniUppercase)
                                .textCase(.uppercase)
                                .lineLimit(1)
                            if let freedomDateText {
                                Text(freedomDateText)
                                    .font(.footnoteSemibold)
                                    .foregroundStyle(AppColors.heroTextPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        if let trailingPercentText {
                            Text(trailingPercentText)
                                .font(.cardFigurePrimary)
                                .foregroundStyle(AppColors.heroTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        Spacer(minLength: 0)
                        Text(footerLabel)
                            .font(.label)
                            .foregroundStyle(AppColors.heroTextHint)
                            .tracking(AppTypography.Tracking.miniUppercase)
                            .textCase(.uppercase)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

// MARK: - Segment bar (supports partial fill)

private struct SegmentBar: View {
    let fillFraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.heroTrack)
                Capsule()
                    .fill(AppColors.heroTrackFill)
                    .frame(width: geo.size.width * min(max(fillFraction, 0), 1))
            }
        }
        .frame(height: 4)
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
