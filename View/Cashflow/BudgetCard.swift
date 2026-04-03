//
//  BudgetCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetCard: View {
    let spending: Spending
    /// 与父视图已加载的 `APIMonthlyBudget` 一致（阶段 0 / 路线图 0.1），避免 Needs/Wants 上限锁死在 MockData。
    let apiBudget: APIMonthlyBudget
    var isConnected: Bool = true
    var hasBudget: Bool = true
    var onSetupBudget: (() -> Void)? = nil
    let onCardTapped: (() -> Void)?
    let onNeedsTapped: (() -> Void)?
    let onWantsTapped: (() -> Void)?

    private var needsColor: Color { AppColors.chartBlue }
    private var wantsColor: Color { AppColors.chartAmber }

    init(
        spending: Spending,
        apiBudget: APIMonthlyBudget,
        isConnected: Bool = true,
        hasBudget: Bool = true,
        onSetupBudget: (() -> Void)? = nil,
        onCardTapped: (() -> Void)? = nil,
        onNeedsTapped: (() -> Void)? = nil,
        onWantsTapped: (() -> Void)? = nil
    ) {
        self.spending = spending
        self.apiBudget = apiBudget
        self.isConnected = isConnected
        self.hasBudget = hasBudget
        self.onSetupBudget = onSetupBudget
        self.onCardTapped = onCardTapped
        self.onNeedsTapped = onNeedsTapped
        self.onWantsTapped = onWantsTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BUDGET")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
                HStack(spacing: AppSpacing.xs) {
                    Text(currentMonthLabel)
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    if isConnected && hasBudget {
                        Image(systemName: "chevron.right")
                            .font(.miniLabel)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
            .contentShape(Rectangle())
            .onTapGesture {
                if isConnected && hasBudget { onCardTapped?() }
            }

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if !isConnected {
                lockedEmptyState
            } else if hasBudget {
                halfRingSection
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.top, AppSpacing.md)
                    .contentShape(Rectangle())
                    .onTapGesture { onCardTapped?() }

                VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                    BudgetRowItem(
                        title: "Needs",
                        amount: formatCurrency(spending.needs),
                        color: needsColor,
                        onTap: onNeedsTapped
                    )
                    BudgetRowItem(
                        title: "Wants",
                        amount: formatCurrency(spending.wants),
                        color: wantsColor,
                        onTap: onWantsTapped
                    )
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.cardPadding)
            } else {
                setupEmptyState
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var lockedEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("$—")
                    .font(.cardFigurePrimary)
                    .foregroundStyle(AppColors.textTertiary)
                Text("/ $—")
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textTertiary)
            }
            Text("Connect accounts to set up a budget")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textTertiary)
            Capsule()
                .fill(AppColors.progressTrack)
                .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.cardPadding)
    }

    private var setupEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Build Your Plan")
                    .font(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Let AI analyze your spending and create a personalized budget.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { onSetupBudget?() }) {
                Text("Start Setup")
                    .font(.statRowSemibold)
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: AppColors.gradientFlamePill,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.cardPadding)
    }

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }

    private var halfRingSection: some View {
        let ringWidth: CGFloat = 200
        let ringHeight: CGFloat = 146
        let lineW: CGFloat = 20
        let safeLimit = max(spending.budgetLimit, 1)
        let needsFrac = CGFloat(min(spending.needs / safeLimit, 1.0)) * 0.5
        let wantsFrac = CGFloat(min(spending.wants / safeLimit, max(0, 1.0 - spending.needs / safeLimit))) * 0.5
        let usedPercent = min(Int((spending.total / safeLimit * 100).rounded()), 999)

        return VStack(spacing: 0) {
            ZStack {
                TopSemiRing(startProgress: 0, endProgress: 1)
                    .stroke(
                        AppColors.progressTrack,
                        style: StrokeStyle(lineWidth: lineW, lineCap: .round)
                    )
                if needsFrac > 0 {
                    TopSemiRing(startProgress: 0, endProgress: needsFrac / 0.5)
                        .stroke(
                            needsColor,
                            style: StrokeStyle(lineWidth: lineW, lineCap: .round)
                        )
                }
                if wantsFrac > 0 {
                    TopSemiRing(
                        startProgress: needsFrac / 0.5,
                        endProgress: (needsFrac + wantsFrac) / 0.5
                    )
                    .stroke(
                        wantsColor,
                        style: StrokeStyle(lineWidth: lineW, lineCap: .round)
                        )
                }

                VStack(spacing: AppSpacing.xs) {
                    Text("\(usedPercent)% used")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.textTertiary)

                    Text(formatCurrency(spending.total))
                        .font(.h2)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("of \(formatCurrency(spending.budgetLimit)) budget")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 68)
            }
            .frame(width: ringWidth, height: ringHeight)
            .frame(maxWidth: .infinity)
            .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity)
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

private struct TopSemiRing: Shape {
    let startProgress: CGFloat
    let endProgress: CGFloat

    func path(in rect: CGRect) -> Path {
        let clampedStart = min(max(startProgress, 0), 1)
        let clampedEnd = min(max(endProgress, 0), 1)
        guard clampedEnd > clampedStart else { return Path() }

        let radius = min(rect.width / 2, rect.height) - 10
        let center = CGPoint(x: rect.midX, y: rect.maxY - 10)
        let startAngle = Double.pi * Double(1 - clampedStart)
        let endAngle = Double.pi * Double(1 - clampedEnd)
        let steps = max(Int(ceil((clampedEnd - clampedStart) * 48)), 2)
        var path = Path()

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let angle = startAngle + (endAngle - startAngle) * progress
            let cosValue = CGFloat(Foundation.cos(angle))
            let sinValue = CGFloat(Foundation.sin(angle))
            let point = CGPoint(
                x: center.x + radius * cosValue,
                y: center.y - radius * sinValue
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private struct BudgetRowItem: View {
    let title: String
    let amount: String
    let color: Color
    let onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap { Button(action: onTap) { rowContent }.buttonStyle(.plain) }
            else { rowContent }
        }
    }

    private var rowContent: some View {
        HStack {
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(color)
                    .frame(width: AppSpacing.sm, height: AppSpacing.sm)
                Text(title)
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(amount)
                    .font(.cardFigureSecondary)
                    .foregroundStyle(AppColors.textPrimary)
                Text("spent")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        BudgetCard(spending: MockData.cashflowData.spending, apiBudget: MockData.apiMonthlyBudget).padding()
    }
}
