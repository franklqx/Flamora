//
//  HomeSavingsRateCard.swift
//  Flamora app
//
//  Home Tab — 4-month savings check-in card.
//  - No progress bar
//  - Each month orb is tappable
//  - Whole card opens full detail
//

import SwiftUI

struct HomeSavingsRateCard: View {
    let snapshot: SavingsTrackingSnapshot?
    var isConnected: Bool = true
    var hasBudgetSetup: Bool = true
    var onMonthTap: (SavingsMonthNode) -> Void
    var onCardTap: () -> Void

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            if isConnected && hasBudgetSetup {
                Button(action: onCardTap) {
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .fill(Color.clear)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                header

                Rectangle()
                    .fill(AppColors.inkDivider)
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

                Group {
                    if !isConnected {
                        placeholderState(
                            title: "Connect accounts to unlock savings tracking",
                            subtitle: "You'll be able to check in month by month from Home."
                        )
                    } else if !hasBudgetSetup {
                        placeholderState(
                            title: "Finish your budget to set a savings target",
                            subtitle: "Once your target is ready, each month will light up as you hit it."
                        )
                    } else if let snapshot {
                        connectedState(snapshot)
                    } else {
                        placeholderState(
                            title: "Loading your savings check-ins",
                            subtitle: "We'll pull in this year's months and your target next."
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Text("SAVINGS RATE")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            Spacer()

            if isConnected && hasBudgetSetup {
                Image(systemName: "chevron.right")
                    .font(.miniLabel)
                    .foregroundColor(AppColors.inkFaint)
                    .padding(.leading, AppSpacing.xs)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
    }

    private func connectedState(_ snapshot: SavingsTrackingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.lg) {
                summaryBlock(
                    label: "Savings Amount",
                    value: savingsAmountText(snapshot)
                )

                Spacer(minLength: AppSpacing.md)

                summaryBlock(
                    label: "Savings Rate",
                    value: "\(Int(snapshot.targetRatePercent.rounded()))%"
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Savings target")
            .accessibilityValue("\(savingsAmountText(snapshot)), \(Int(snapshot.targetRatePercent.rounded())) percent of income")

            HStack(alignment: .top, spacing: AppSpacing.sm + AppSpacing.xs) {
                ForEach(snapshot.currentWindowNodes) { node in
                    Button {
                        guard node.isEditable else { return }
                        onMonthTap(node)
                    } label: {
                        SavingsMonthOrb(node: node, diameter: 50)
                            .opacity(node.isEditable ? 1.0 : 0.72)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(!node.isEditable)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)
            Text(value)
                .font(.figureMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
        }
    }

    private func savingsAmountText(_ snapshot: SavingsTrackingSnapshot) -> String {
        "\(formatCurrency(snapshot.targetAmount))/month"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func placeholderState(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: AppSpacing.xs) {
                        Circle()
                            .fill(AppColors.inkTrack)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.inkBorder, lineWidth: 1)
                            )
                        Capsule()
                            .fill(AppColors.inkTrack)
                            .frame(width: 26, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            Text(title)
                .font(.bodySemibold)
                .foregroundStyle(AppColors.inkPrimary)

            Text(subtitle)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Connected") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()

        HomeSavingsRateCard(
            snapshot: SavingsTrackingBuilder.snapshot(
                year: 2026,
                monthlyAmounts: [950, 620, nil, 1_300, nil, nil, nil, nil, nil, nil, nil, nil],
                targetAmount: 1_000,
                targetRatePercent: 18
            ),
            isConnected: true,
            hasBudgetSetup: true,
            onMonthTap: { _ in },
            onCardTap: {}
        )
        .padding()
    }
}

#Preview("Locked") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()

        HomeSavingsRateCard(
            snapshot: nil,
            isConnected: false,
            hasBudgetSetup: false,
            onMonthTap: { _ in },
            onCardTap: {}
        )
        .padding()
    }
}
