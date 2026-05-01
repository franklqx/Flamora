//
//  BudgetCard.swift
//  Flamora app
//
//  L1 budget summary on the Cash Flow main page.
//  - Ring shows total spent vs sum of subcategory budgets; turns red when over.
//  - Two rows below split today's spend into Needs vs Wants by share.
//  - All subcategory detail lives in L2 (Total / Needs / Wants Spending).
//

import SwiftUI

struct BudgetCard: View {
    let spending: Spending
    let apiBudget: APIMonthlyBudget
    var isConnected: Bool = true
    var hasBudget: Bool = true
    var onSetupBudget: (() -> Void)? = nil
    let onCardTapped: (() -> Void)?
    let onNeedsTapped: (() -> Void)?
    let onWantsTapped: (() -> Void)?
    var onAdjustOverallPlan: (() -> Void)? = nil
    var onEditCategoryBudgets: (() -> Void)? = nil
    var displayMonth: Date = Date()
    var onMonthLabelTapped: (() -> Void)? = nil

    @State private var showEditChooser = false

    private var needsColor: Color { AppColors.budgetNeedsBlue }
    private var wantsColor: Color { AppColors.budgetWantsPurple }
    private var overBudgetColor: Color { AppColors.error }
    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// `apiBudget.needsBudget` / `wantsBudget` are derived sums of the user's
    /// subcategory budgets — Needs and Wants themselves have no user-facing
    /// budget, they're just classification labels.
    private var totalBudget: Double { max(apiBudget.needsBudget + apiBudget.wantsBudget, 0) }
    private var totalSpent: Double { max(spending.needs + spending.wants, 0) }
    private var isOverBudget: Bool { totalBudget > 0 && totalSpent > totalBudget }
    private var overByAmount: Double { max(totalSpent - totalBudget, 0) }
    private var usedPercent: Int {
        guard totalBudget > 0 else { return 0 }
        return Int((totalSpent / totalBudget * 100).rounded())
    }
    private var needsShare: Double {
        totalSpent > 0 ? max(spending.needs, 0) / totalSpent : 0
    }
    private var wantsShare: Double {
        totalSpent > 0 ? max(spending.wants, 0) / totalSpent : 0
    }
    private var isShowingCurrentMonth: Bool {
        Calendar.current.isDate(displayMonth, equalTo: Date(), toGranularity: .month)
    }

    init(
        spending: Spending,
        apiBudget: APIMonthlyBudget,
        isConnected: Bool = true,
        hasBudget: Bool = true,
        onSetupBudget: (() -> Void)? = nil,
        onCardTapped: (() -> Void)? = nil,
        onNeedsTapped: (() -> Void)? = nil,
        onWantsTapped: (() -> Void)? = nil,
        onAdjustOverallPlan: (() -> Void)? = nil,
        onEditCategoryBudgets: (() -> Void)? = nil,
        displayMonth: Date = Date(),
        onMonthLabelTapped: (() -> Void)? = nil
    ) {
        self.spending = spending
        self.apiBudget = apiBudget
        self.isConnected = isConnected
        self.hasBudget = hasBudget
        self.onSetupBudget = onSetupBudget
        self.onCardTapped = onCardTapped
        self.onNeedsTapped = onNeedsTapped
        self.onWantsTapped = onWantsTapped
        self.onAdjustOverallPlan = onAdjustOverallPlan
        self.onEditCategoryBudgets = onEditCategoryBudgets
        self.displayMonth = displayMonth
        self.onMonthLabelTapped = onMonthLabelTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if hasBudget {
                budgetDisplaySection
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
            } else {
                setupEmptyState
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showEditChooser) {
            BudgetEditChooserSheet(
                onAdjustOverallPlan: { onAdjustOverallPlan?() },
                onEditCategoryBudgets: { onEditCategoryBudgets?() }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("BUDGET")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isConnected && hasBudget { onCardTapped?() }
                }

            Spacer()

            Button {
                if isConnected && hasBudget { onMonthLabelTapped?() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(monthLabel)
                        .font(.cardHeader)
                        .foregroundColor(AppColors.inkPrimary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    if isConnected && hasBudget {
                        Image(systemName: "chevron.right")
                            .font(.miniLabel)
                            .foregroundColor(AppColors.inkFaint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!(isConnected && hasBudget))
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
    }

    private var budgetDisplaySection: some View {
        VStack(spacing: AppSpacing.lg) {
            ringSection
            VStack(spacing: AppSpacing.md) {
                bucketRow(
                    title: "Needs",
                    spent: spending.needs,
                    share: needsShare,
                    color: needsColor,
                    onTap: onNeedsTapped
                )
                bucketRow(
                    title: "Wants",
                    spent: spending.wants,
                    share: wantsShare,
                    color: wantsColor,
                    onTap: onWantsTapped
                )
            }
        }
    }

    private var ringSection: some View {
        let safeNeedsBudget = max(apiBudget.needsBudget, 0)
        let safeWantsBudget = max(apiBudget.wantsBudget, 0)
        let safeTotalBudget = max(safeNeedsBudget + safeWantsBudget, 0)
        let denom = max(safeTotalBudget, 1)
        // Always show needs/wants split — even when over budget, the colored
        // arcs cap at each bucket's allocation so the visual proportion is
        // preserved. Over-budget is signaled by an outer red warning ring +
        // red center text, never by hiding the split.
        let needsArcFraction = min(max(spending.needs, 0), safeNeedsBudget) / denom
        let wantsArcFraction = min(max(spending.wants, 0), safeWantsBudget) / denom

        return ZStack {
            // Outer red warning ring rendered slightly outside the main 16pt
            // stroke so it doesn't overlap the colored arcs.
            if isOverBudget {
                Circle()
                    .stroke(overBudgetColor.opacity(0.85), lineWidth: 4)
                    .padding(-8)
            }

            Circle()
                .stroke(AppColors.inkTrack, lineWidth: 16)
            if needsArcFraction > 0 {
                ringArc(start: 0, fraction: needsArcFraction)
                    .stroke(needsColor, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            if wantsArcFraction > 0 {
                ringArc(start: needsArcFraction, fraction: wantsArcFraction)
                    .stroke(wantsColor, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: AppSpacing.xs) {
                Text("\(max(usedPercent, 0))% used")
                    .font(.footnoteRegular)
                    .foregroundColor(isOverBudget ? overBudgetColor : AppColors.inkSoft)
                Text(formatCurrency(max(totalSpent, 0)))
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("of \(formatCurrency(safeTotalBudget)) budget")
                    .font(.caption)
                    .foregroundColor(AppColors.inkFaint)
                if isOverBudget {
                    Text("Over by \(formatCurrency(overByAmount))")
                        .font(.footnoteSemibold)
                        .foregroundColor(overBudgetColor)
                        .padding(.top, 2)
                }
                if isConnected && hasBudget && isShowingCurrentMonth {
                    Button {
                        showEditChooser = true
                    } label: {
                        Text("Edit budget")
                            .font(.caption)
                            .foregroundColor(AppColors.inkPrimary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.sm)
        }
        .frame(width: 178, height: 178)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if isConnected && hasBudget { onCardTapped?() }
        }
    }

    private func bucketRow(
        title: String,
        spent: Double,
        share: Double,
        color: Color,
        onTap: (() -> Void)?
    ) -> some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.bodySemibold)
                        .foregroundColor(AppColors.inkPrimary)
                    Spacer()
                    Text(formatCurrency(max(spent, 0)))
                        .font(.bodySemibold)
                        .foregroundColor(AppColors.inkPrimary)
                        .monospacedDigit()
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.inkSoft)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                GeometryReader { geo in
                    let width = max(geo.size.width, 0)
                    let clamped = min(max(share, 0), 1)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.inkTrack)
                            .frame(height: 5)
                        Capsule()
                            .fill(color)
                            .frame(width: width * clamped, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
            .padding(.vertical, AppSpacing.sm)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var setupEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Build Your Plan")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("Let AI analyze your spending and create a personalized budget.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
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

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: displayMonth).uppercased()
    }

    private func ringArc(start: Double, fraction: Double) -> some Shape {
        Circle()
            .trim(from: max(0, min(start, 1)), to: max(0, min(start + fraction, 1)))
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
        AppColors.backgroundPrimary.ignoresSafeArea()
        BudgetCard(
            spending: MockData.cashflowData.spending,
            apiBudget: MockData.apiMonthlyBudget
        )
        .padding()
    }
}
