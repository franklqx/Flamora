//
//  FIRECountdownCard.swift
//  Flamora app
//
//  OLDDESIGN — hero card used by archived `JourneyView.swift`; live Home uses `HomeHeroCardSurface`.
//  Phase 4: state-driven hero shell for the rebuilt Home experience.
//

import SwiftUI

struct FIRECountdownCard: View {
    let hero: HomeHeroModel?
    let stage: HomeSetupStage
    var onPrimaryAction: (() -> Void)? = nil
    var fixedHeight: CGFloat? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColors.surface)

            RoundedRectangle(cornerRadius: AppRadius.card)
                .strokeBorder(
                    LinearGradient(
                        colors: AppColors.gradientFire,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            VStack(alignment: .leading, spacing: 0) {
                Text(heroHeader)
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(AppTypography.Tracking.cardHeader)
                    .padding(.bottom, AppSpacing.md)

                if stage == .noGoal {
                    noGoalState
                } else if let hero {
                    // Old users may have a goal with no target_retirement_age (pre-S1-1).
                    // Show a CTA to complete setup rather than rendering a misleading hero.
                    if (hero.targetRetirementAge ?? 0) > 0 {
                        loadedState(hero: hero)
                    } else {
                        incompleteGoalState
                    }
                } else if stage == .goalSet {
                    connectState
                } else {
                    skeletonState
                }
            }
            .padding(AppSpacing.cardPadding)
        }
        .frame(height: fixedHeight, alignment: .top)
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - View States

private extension FIRECountdownCard {
    var heroHeader: String {
        switch stage {
        case .noGoal:
            return "START YOUR FIRE JOURNEY"
        case .goalSet:
            return "YOUR FIRE STARTING POINT"
        case .accountsLinked, .snapshotPending, .planPending, .active:
            return "YOUR FIRE JOURNEY"
        }
    }

    var noGoalState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Set your goal to unlock your real path.")
                    .font(.h4)
                    .foregroundStyle(AppColors.textPrimary)

                Text("We'll use your target retirement spending to estimate your FIRE number and build the rest of your setup.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
            }

            if let onPrimaryAction {
                Button(action: onPrimaryAction) {
                    Text("Set My Goal")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }
                .buttonStyle(.plain)
            }
        }
    }

    var connectState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Connect your accounts to reveal your real starting point.")
                    .font(.h4)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Once we can see your cash, credit, and investment accounts, your official progress will replace this teaser.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
            }

            if let onPrimaryAction {
                Button(action: onPrimaryAction) {
                    Text("Continue Setup")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Shown when a goal exists (stage = .active) but target_retirement_age is nil.
    /// Guides the user back into Budget Setup to complete the missing field.
    var incompleteGoalState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("One more detail needed.")
                    .font(.h4)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Set your target retirement age to unlock your FIRE countdown and projected path.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
            }

            if let onPrimaryAction {
                Button(action: onPrimaryAction) {
                    Text("Complete goal setup")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }
                .buttonStyle(.plain)
            }
        }
    }

    func loadedState(hero: HomeHeroModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text("\(Int(hero.progressPercentage.rounded()))%")
                    .font(.cardFigurePrimary)
                    .foregroundStyle(AppColors.textPrimary)

                Text("of the way there")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.xs)

            Text(hero.progressStatus)
                .font(.bodySmall)
                .foregroundStyle(AppColors.overlayWhiteOnGlass)
                .lineSpacing(3)
                .padding(.bottom, AppSpacing.md)

            GeometryReader { geo in
                let width = max(0, geo.size.width)
                let fraction = max(0, min(hero.progressPercentage / 100, 1))
                let fillWidth = max(0, width * fraction)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.overlayWhiteStroke)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: AppColors.gradientFire,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.bottom, AppSpacing.sm)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(startDateLabel(iso: hero.createdAt))
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Started")
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(hero.displayFireDate ?? "Estimating")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)

                    if let label = hero.activePlanLabel, !label.isEmpty {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(AppColors.textMuted)
                    } else {
                        Text("\(hero.fireNumberFormatted) target")
                            .font(.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FIRE goal progress")
        .accessibilityValue(
            "\(Int(hero.progressPercentage.rounded())) percent. Estimated FIRE date \(hero.displayFireDate ?? "unknown")."
        )
    }

    var skeletonState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            skeletonBlock(width: 120, height: 32)
            skeletonBlock(width: .infinity, height: 14)
            skeletonBlock(width: .infinity, height: 8)
            HStack {
                skeletonBlock(width: 80, height: 12)
                Spacer()
                skeletonBlock(width: 80, height: 12)
            }
        }
    }

    func skeletonBlock(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppColors.surfaceElevated)
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height, maxHeight: height)
    }

    func startDateLabel(iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso)
            ?? ISO8601DateFormatter().date(from: iso)
            ?? Date()
        let display = DateFormatter()
        display.dateFormat = "MMM d, yyyy"
        return display.string(from: date)
    }
}

// MARK: - Preview

#Preview("No Goal") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        FIRECountdownCard(hero: nil, stage: .noGoal, onPrimaryAction: {})
    }
}

#Preview("Connected Teaser") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        FIRECountdownCard(hero: nil, stage: .goalSet, onPrimaryAction: {})
    }
}

#Preview("Loaded") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        FIRECountdownCard(
            hero: HomeHeroModel(
                goalId: "1",
                dataSource: "plaid",
                fireNumber: 2_400_000,
                currentNetWorth: 672_000,
                progressPercentage: 28,
                gapToFire: 1_728_000,
                onTrack: true,
                officialFireDate: "Mar 2042",
                officialFireAge: 49,
                officialYearsRemaining: 16,
                progressStatus: "Your current path is improving.",
                activePlanType: "recommended",
                activePlanLabel: "Recommended",
                savingsTargetMonthly: 1200,
                retirementSpendingMonthly: 5000,
                lifestylePreset: "current",
                targetRetirementAge: nil,
                currentAge: 33,
                requiredSavingsRate: 27,
                yearsRemaining: 16,
                createdAt: "2026-04-06T09:00:00Z"
            ),
            stage: .active
        )
    }
}
