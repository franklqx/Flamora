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
    var onAdd: () -> Void
    var onCardTap: (() -> Void)? = nil

    private var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 6) {
                    Text("SAVINGS TARGET")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(0.8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.cardPadding)
                .padding(.bottom, 12)

                Rectangle()
                    .fill(AppColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

                VStack(alignment: .leading, spacing: 0) {
                    if currentAmount > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(formatCurrency(currentAmount))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                            Text("/ \(formatCurrency(targetAmount))")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.top, AppSpacing.md)
                    } else {
                        Text(formatCurrency(targetAmount))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, AppSpacing.md)
                    }

                    if currentAmount > 0 {
                        VStack(spacing: 10) {
                            HStack {
                                Text("CURRENT STATUS")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                                    .tracking(0.6)
                                Spacer()
                                Text("\(Int(progress * 100))% ACHIEVED")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .tracking(0.4)
                            }
                            .padding(.top, 14)

                            progressBar
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onCardTap?() }
            }

            if currentAmount <= 0 {
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
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
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
                    .fill(Color.white)
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
