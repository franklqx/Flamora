//
//  SavingsTargetCard.swift
//  Flamora app
//
//  Savings target summary card - reference design style
//

import SwiftUI

struct SavingsTargetCard: View {
    @Binding var currentAmount: Double
    var targetAmount: Double
    var isConnected: Bool = true
    var onAdd: () -> Void
    var onCardTap: (() -> Void)? = nil

    private var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    /// Actual % of target (can exceed 100% when over-saving).
    private var achievedPercent: Int {
        guard targetAmount > 0 else { return 0 }
        return Int((currentAmount / targetAmount * 100).rounded())
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("SAVINGS TARGET")
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Spacer()
                    HStack(spacing: AppSpacing.xs) {
                        Text(currentMonthLabel)
                            .font(.cardHeader)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(AppTypography.Tracking.cardHeader)
                        if isConnected {
                            Image(systemName: "chevron.right")
                                .font(.miniLabel)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

                Rectangle()
                    .fill(AppColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

                Group {
                    if isConnected {
                        VStack(alignment: .leading, spacing: 0) {
                            if currentAmount > 0 {
                                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                                    Text(formatCurrency(currentAmount))
                                        .font(.cardFigurePrimary)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("/ \(formatCurrency(targetAmount))")
                                        .font(.bodyRegular)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.textTertiary)
                                }
                                .padding(.top, AppSpacing.md)
                            } else {
                                Text(formatCurrency(targetAmount))
                                    .font(.cardFigurePrimary)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .padding(.top, AppSpacing.md)
                            }

                            if currentAmount > 0 {
                                VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                                    HStack {
                                        Text("CURRENT STATUS")
                                            .font(.segmentLabel(selected: false))
                                            .foregroundColor(AppColors.textTertiary)
                                            .tracking(AppTypography.Tracking.miniUppercase)
                                        Spacer()
                                        Text("\(achievedPercent)% ACHIEVED")
                                            .font(.segmentLabel(selected: true))
                                            .foregroundStyle(AppColors.textPrimary)
                                            .tracking(AppTypography.Tracking.miniUppercase)
                                    }
                                    .padding(.top, AppSpacing.md - AppSpacing.xs)

                                    progressBar
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                                Text("$—")
                                    .font(.cardFigurePrimary)
                                    .foregroundStyle(AppColors.textTertiary)
                                Text("/ \(formatCurrency(targetAmount))")
                                    .font(.bodyRegular)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.top, AppSpacing.md)
                            Text("Connect accounts to track savings")
                                .font(.footnoteRegular)
                                .foregroundStyle(AppColors.textTertiary)
                            Capsule()
                                .fill(AppColors.progressTrack)
                                .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if isConnected { onCardTap?() } }
            }

            if currentAmount <= 0 && isConnected {
                Button(action: onAdd) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: AppColors.gradientFlamePill,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "plus")
                            .font(.h4)
                            .foregroundStyle(AppColors.textInverse)
                    }
                }
                .buttonStyle(.plain)
                // Below header row so it does not overlap month + chevron
                .padding(.top, AppSpacing.cardPadding + AppSpacing.md + AppSpacing.sm + AppSpacing.xs)
                .padding(.trailing, AppSpacing.cardPadding)
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeW = w.isFinite && w >= 0 ? w : 0
            let pW = max(0, safeW * CGFloat(max(0, min(progress, 1.0))))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.progressTrack)
                    .frame(height: 6)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: pW, height: 6)
            }
        }
        .frame(height: 6)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SavingsTargetCard(currentAmount: .constant(2100), targetAmount: 2000, onAdd: {}).padding()
    }
}
