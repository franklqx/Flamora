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

    /// Filled segment count for the strip (0...totalSegments).
    /// In active mode the fill follows portfolio-toward-FIRE progress, computed
    /// client-side from `portfolioTotal / fireNumber` so it matches what the
    /// build-plan flow used to size the goal.
    static func filledSegments(
        for stage: HomeSetupStage,
        hero: HomeHeroModel?,
        portfolioTotal: Double? = nil
    ) -> Int {
        switch stage {
        case .noGoal, .goalSet:
            return 3
        case .accountsLinked:
            return 5
        case .snapshotPending:
            return 7
        case .planPending:
            return 9
        case .active:
            let progress = activeProgress(hero: hero, portfolioTotal: portfolioTotal)
            return min(
                totalSegments,
                max(0, Int(round(progress * Double(totalSegments))))
            )
        }
    }

    /// 0..1 portfolio progress toward FIRE. Returns 0 when inputs are missing.
    static func activeProgress(hero: HomeHeroModel?, portfolioTotal: Double?) -> Double {
        guard let hero, hero.fireNumber > 0 else { return 0 }
        let portfolio = portfolioTotal ?? hero.startingPortfolioBalance ?? 0
        return min(max(portfolio / hero.fireNumber, 0), 1)
    }

    /// Only when active and hero data exists (per product: no misleading % before setup).
    static func trailingPercentText(
        stage: HomeSetupStage,
        hero: HomeHeroModel?,
        portfolioTotal: Double? = nil
    ) -> String? {
        guard stage == .active, hero != nil else { return nil }
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
    let filledSegments: Int
    let footerLabel: String
    let trailingPercentText: String?

    /// When the user has an active plan we render a richer layout: DAY counter
    /// chip, current portfolio amount on the left, FIRE target on the right,
    /// and a Freedom Date stamp in the bottom-right. All four are optional —
    /// missing values fall back to the setup layout (subtitle row + percent).
    let dayCount: Int?
    let startAmountText: String?
    let targetAmountText: String?
    let freedomDateText: String?

    init(
        title: String = "YOUR FIRE JOURNEY",
        subtitle: String = "Finish the set up to track your progress.",
        totalSegments: Int = HomeJourneyProgressMapping.totalSegments,
        filledSegments: Int,
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
        self.filledSegments = min(totalSegments, max(0, filledSegments))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.inlineFigureBold)
                    .foregroundStyle(AppColors.heroTextPrimary)
                    .tracking(AppTypography.Tracking.miniUppercase)

                Spacer(minLength: AppSpacing.sm)

                if let dayCount {
                    Text("DAY \(dayCount)")
                        .font(.smallLabel)
                        .foregroundStyle(AppColors.heroTextPrimary)
                        .tracking(AppTypography.Tracking.miniUppercase)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .stroke(AppColors.heroTextPrimary.opacity(0.4), lineWidth: 1)
                        )
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
                        RoundedRectangle(cornerRadius: AppRadius.full)
                            .fill(index < filledSegments ? AppColors.heroTrackFill : AppColors.heroTrack)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("FIRE progress")
                .accessibilityValue("\(filledSegments) of \(totalSegments) segments")

                if isActiveLayout {
                    HStack(alignment: .firstTextBaseline) {
                        if let startAmountText {
                            Text(startAmountText)
                                .font(.footnoteBold)
                                .foregroundStyle(AppColors.heroTextPrimary)
                        }
                        Spacer(minLength: 0)
                        if let targetAmountText {
                            Text(targetAmountText)
                                .font(.footnoteBold)
                                .foregroundStyle(AppColors.heroTextPrimary)
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
                            if let freedomDateText {
                                Text(freedomDateText)
                                    .font(.footnoteSemibold)
                                    .foregroundStyle(AppColors.heroTextPrimary)
                            }
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        if let trailingPercentText {
                            Text(trailingPercentText)
                                .font(.cardFigurePrimary)
                                .foregroundStyle(AppColors.heroTextPrimary)
                        }
                        Spacer(minLength: 0)
                        Text(footerLabel)
                            .font(.label)
                            .foregroundStyle(AppColors.heroTextHint)
                            .tracking(AppTypography.Tracking.miniUppercase)
                            .textCase(.uppercase)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
        let filled = HomeJourneyProgressMapping.filledSegments(
            for: stage,
            hero: homeHero,
            portfolioTotal: portfolioTotal
        )
        let percent = HomeJourneyProgressMapping.trailingPercentText(
            stage: stage,
            hero: homeHero,
            portfolioTotal: portfolioTotal
        )

        let isActive = stage == .active && homeHero != nil
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
            filledSegments: filled,
            trailingPercentText: percent,
            dayCount: isActive ? daysSincePlanStart : nil,
            startAmountText: startText,
            targetAmountText: targetText,
            freedomDateText: isActive ? freedomDateText : nil
        )
    }

    private static func formatHeroAmount(_ value: Double) -> String {
        if value >= 1_000_000 {
            let m = value / 1_000_000
            if m >= 10 { return String(format: "$%.0fM", m) }
            return String(format: "$%.1fM", m)
        }
        if value >= 1_000 {
            let k = value / 1_000
            if k >= 100 { return String(format: "$%.0fK", k) }
            return String(format: "$%.1fK", k)
        }
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
