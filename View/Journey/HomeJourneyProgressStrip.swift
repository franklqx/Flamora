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
    static func filledSegments(for stage: HomeSetupStage, hero: HomeHeroModel?) -> Int {
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
            guard let hero else { return 9 }
            let p = hero.progressPercentage
            return min(
                totalSegments,
                max(0, Int(round(p / 100.0 * Double(totalSegments))))
            )
        }
    }

    /// Only when active and hero data exists (per product: no misleading % before setup).
    static func trailingPercentText(stage: HomeSetupStage, hero: HomeHeroModel?) -> String? {
        guard stage == .active, let hero else { return nil }
        return "\(Int(hero.progressPercentage.rounded()))%"
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

    init(
        title: String = "YOUR FIRE JOURNEY",
        subtitle: String = "Finish the set up to track your progress.",
        totalSegments: Int = HomeJourneyProgressMapping.totalSegments,
        filledSegments: Int,
        footerLabel: String = "FREEDOM DATE",
        trailingPercentText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.totalSegments = totalSegments
        self.filledSegments = min(totalSegments, max(0, filledSegments))
        self.footerLabel = footerLabel
        self.trailingPercentText = trailingPercentText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.inlineFigureBold)
                .foregroundStyle(AppColors.heroTextPrimary)
                .tracking(AppTypography.Tracking.miniUppercase)
                .padding(.bottom, AppSpacing.sm)

            Text(subtitle)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.heroTextFaint)
                .lineSpacing(3)
                .padding(.bottom, AppSpacing.md)

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
                .accessibilityLabel("Setup progress")
                .accessibilityValue("\(filledSegments) of \(totalSegments) segments")

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
        .padding(.horizontal, AppSpacing.screenPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Factory (Hero layer only)

extension HomeJourneyProgressStrip {
    /// Progress copy + track laid on the brand gradient (no card background).
    static func heroEmbedded(
        stage: HomeSetupStage,
        homeHero: HomeHeroModel?
    ) -> HomeJourneyProgressStrip {
        let filled = HomeJourneyProgressMapping.filledSegments(for: stage, hero: homeHero)
        let percent = HomeJourneyProgressMapping.trailingPercentText(stage: stage, hero: homeHero)
        return HomeJourneyProgressStrip(
            filledSegments: filled,
            trailingPercentText: percent
        )
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
