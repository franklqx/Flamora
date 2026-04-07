//
//  FIRECountdownCard.swift
//  Flamora app
//
//  Hero card on JourneyView showing FIRE progress %.
//  Progress bar acts as a timeline: left anchor = start date, right anchor = FIRE arrival date.
//
//  • Data: APIFireGoal (progressPercentage, yearsRemaining, fireNumber, createdAt)
//  • States: loading (nil fireGoal), empty (no bank), loaded
//  • Fire gradient border stroke (1pt) to differentiate from PortfolioCard
//

import SwiftUI

struct FIRECountdownCard: View {

    /// nil = still loading; use skeleton
    let fireGoal: APIFireGoal?
    var isConnected: Bool = true
    var onConnectTapped: (() -> Void)? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColors.surface)

            // Fire gradient border (1pt stroke)
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
                // Header
                Text("YOUR FIRE JOURNEY")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(AppTypography.Tracking.cardHeader)
                    .padding(.bottom, AppSpacing.md)

                if !isConnected {
                    emptyState
                } else if let goal = fireGoal {
                    loadedState(goal: goal)
                } else {
                    skeletonState
                }
            }
            .padding(AppSpacing.cardPadding)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    // MARK: - Loaded

    private func loadedState(goal: APIFireGoal) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Primary metric
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text("\(Int(goal.progressPercentage.rounded()))%")
                    .font(.cardFigurePrimary)
                    .foregroundStyle(AppColors.textPrimary)
                Text("of the way there")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.sm)

            // Gradient progress bar (timeline)
            GeometryReader { geo in
                let width = max(0, geo.size.width)
                let fraction = max(0, min(goal.progressPercentage / 100, 1))
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

            // Timeline anchors: start date (left) — FIRE arrival (right)
            HStack(alignment: .top) {
                // Left anchor: when the user started
                VStack(alignment: .leading, spacing: 2) {
                    Text(startDateLabel(iso: goal.createdAt))
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Started")
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                }

                Spacer()

                // Right anchor: estimated FIRE date + target amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text(fireDateLabel(yearsRemaining: goal.yearsRemaining))
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)
                    Text("\(formatCurrency(goal.fireNumber)) target")
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FIRE goal progress")
        .accessibilityValue(
            "\(Int(goal.progressPercentage.rounded())) percent. Estimated FIRE date \(fireDateLabel(yearsRemaining: goal.yearsRemaining))."
        )
    }

    // MARK: - Skeleton

    private var skeletonState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            skeletonBlock(width: 120, height: 32)
            skeletonBlock(width: .infinity, height: 8)
            HStack {
                skeletonBlock(width: 80, height: 12)
                Spacer()
                skeletonBlock(width: 80, height: 12)
            }
        }
    }

    private func skeletonBlock(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppColors.surfaceElevated)
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height, maxHeight: height)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Connect your bank to see your FIRE progress")
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)

            Button(action: { onConnectTapped?() }) {
                Text("Connect Accounts")
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

    // MARK: - Helpers

    /// Parse ISO 8601 createdAt and format as "Apr 6, 2026"
    private func startDateLabel(iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso)
            ?? ISO8601DateFormatter().date(from: iso)
            ?? Date()
        let display = DateFormatter()
        display.dateFormat = "MMM d, yyyy"
        return display.string(from: date)
    }

    /// Compute estimated FIRE arrival month+year from yearsRemaining
    private func fireDateLabel(yearsRemaining: Int) -> String {
        guard yearsRemaining > 0 else { return "Now" }
        let arrival = Calendar.current.date(
            byAdding: .year,
            value: yearsRemaining,
            to: Date()
        ) ?? Date()
        let display = DateFormatter()
        display.dateFormat = "MMM d, yyyy"
        return display.string(from: arrival)
    }

    /// Format large currency values compactly: $2.4M, $340K, $28K
    private func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            let m = value / 1_000_000
            return String(format: "$%.1fM", m)
        } else if value >= 1_000 {
            let k = value / 1_000
            return String(format: "$%.0fK", k)
        }
        return String(format: "$%.0f", value)
    }
}

// MARK: - Preview

#Preview("Loaded") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 16) {
            FIRECountdownCard(
                fireGoal: APIFireGoal(
                    goalId: "1",
                    fireNumber: 2_400_000,
                    currentNetWorth: 672_000,
                    gapToFire: 1_728_000,
                    requiredSavingsRate: 32,
                    targetRetirementAge: 50,
                    currentAge: 32,
                    yearsRemaining: 14,
                    progressPercentage: 28,
                    onTrack: true,
                    createdAt: "2026-04-06T09:00:00Z"
                ),
                isConnected: true
            )
        }
    }
}

#Preview("Loading") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        FIRECountdownCard(fireGoal: nil, isConnected: true)
    }
}

#Preview("Not connected") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        FIRECountdownCard(fireGoal: nil, isConnected: false, onConnectTapped: {})
    }
}

#Preview("Near FIRE") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        FIRECountdownCard(
            fireGoal: APIFireGoal(
                goalId: "2",
                fireNumber: 2_400_000,
                currentNetWorth: 2_160_000,
                gapToFire: 240_000,
                requiredSavingsRate: 8,
                targetRetirementAge: 50,
                currentAge: 49,
                yearsRemaining: 1,
                progressPercentage: 90,
                onTrack: true,
                createdAt: "2018-01-15T09:00:00Z"
            ),
            isConnected: true
        )
    }
}
