//
//  BS_SpendingBreakdownView.swift
//  Flamora app
//
//  Budget Setup — Step 3: Where Your Money Goes
//  V2: Donut chart (Needs vs Wants), category detail cards, tip banner
//

import SwiftUI

struct BS_SpendingBreakdownView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @State private var selectedSegment: Segment? = nil
    @State private var showAllNeeds = false
    @State private var showAllWants = false

    private let gradientColors = [Color(hex: "F5C842"), Color(hex: "E88BC4")]
    private let purpleColor = Color(hex: "C084FC")
    private let tealColor = Color(hex: "34D399")

    /// 甜甜圈选中扇区（与 API 字段 `avg_monthly_fixed` / `avg_monthly_flexible` 对应为 Needs / Wants）。
    private enum Segment {
        case needs, wants
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundSecondary.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    donutChartCard
                        .padding(.horizontal, AppSpacing.lg)

                    needsExpensesCard
                        .padding(.horizontal, AppSpacing.lg)

                    wantsSpendingCard
                        .padding(.horizontal, AppSpacing.lg)

                    tipBanner
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button { viewModel.goBack() } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.sm)

            Text("Your Spending Breakdown")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Text("We categorized your spending into needs and wants.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Donut Chart Card

    private var donutChartCard: some View {
        let stats = viewModel.spendingStats
        let needsMonthly = stats?.avgMonthlyFixed ?? 0
        let wantsMonthly = stats?.avgMonthlyFlexible ?? 0
        let total = needsMonthly + wantsMonthly
        let needsFrac = total > 0 ? needsMonthly / total : 0.5

        // Full 360° ring with lineCap: .round — rounded caps on each segment's
        // endpoints naturally create a visual gap at the junctions (Apple Fitness style).
        let needsFracCaptured = needsFrac

        let centerLabel: String = {
            switch selectedSegment {
            case .needs: return "NEEDS"
            case .wants: return "WANTS"
            case nil:    return "MONTHLY AVG"
            }
        }()
        let centerAmount: Double = {
            switch selectedSegment {
            case .needs: return needsMonthly
            case .wants: return wantsMonthly
            case nil:    return total
            }
        }()

        return VStack(spacing: AppSpacing.lg) {
            ZStack {
                // Background track (full ring, very subtle)
                Circle()
                    .stroke(AppColors.overlayWhiteWash, lineWidth: 20)
                    .frame(width: 170, height: 170)

                // Needs arc (purple) — rounded caps
                Circle()
                    .trim(from: 0, to: needsFracCaptured)
                    .stroke(
                        purpleColor.opacity(selectedSegment == .wants ? 0.2 : 1),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))

                // Wants arc (teal) — rounded caps
                Circle()
                    .trim(from: needsFracCaptured, to: 1.0)
                    .stroke(
                        tealColor.opacity(selectedSegment == .needs ? 0.2 : 1),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))

                // Center text: label above, amount below
                VStack(spacing: AppSpacing.xs) {
                    Text(centerLabel)
                        .font(.label)
                        .tracking(0.8)
                        .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                    Text("$\(formattedInt(centerAmount))")
                        .font(.h2)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                }
                .animation(.easeOut(duration: 0.2), value: selectedSegment)

                // Invisible center hit area — tap to deselect
                Circle()
                    .fill(Color.clear)
                    .frame(width: 122, height: 122)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { selectedSegment = nil }
                    }
            }
            .animation(.easeOut(duration: 0.2), value: selectedSegment)

            // Clickable legend (also tap the arc colors to select)
            HStack(spacing: AppSpacing.lg) {
                legendButton(color: purpleColor, label: "Needs", amount: needsMonthly, segment: .needs)
                legendButton(color: tealColor, label: "Wants", amount: wantsMonthly, segment: .wants)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func legendButton(color: Color, label: String, amount: Double, segment: Segment) -> some View {
        let isSelected = selectedSegment == segment
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedSegment = isSelected ? nil : segment
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Circle().fill(color).frame(width: AppSpacing.sm, height: AppSpacing.sm)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("$\(formattedInt(amount))")
                        .font(.statRowSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? color.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Needs（数据来自 API `fixed_expenses` / avg_monthly_fixed）

    private var needsExpensesCard: some View {
        let allItems = (viewModel.spendingStats?.fixedExpenses ?? [])
            .sorted { $0.avgMonthlyAmount > $1.avgMonthlyAmount }
        let total = viewModel.spendingStats?.avgMonthlyFixed ?? 0
        let maxAmount = allItems.map(\.avgMonthlyAmount).max() ?? 1
        let visibleItems = showAllNeeds ? allItems : Array(allItems.prefix(4))
        let hasMore = allItems.count > 4

        return VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
            HStack {
                HStack(spacing: AppSpacing.sm) {
                    Circle().fill(purpleColor).frame(width: AppSpacing.sm, height: AppSpacing.sm)
                    Text("Needs")
                        .font(.figureSecondarySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                Text("$\(formattedInt(total))")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
            }

            ForEach(visibleItems) { item in
                categoryRow(
                    emoji: CategoryDisplay.emoji(item.name),
                    name: CategoryDisplay.displayName(item.name),
                    amount: item.avgMonthlyAmount,
                    maxAmount: maxAmount,
                    barColor: purpleColor
                )
            }

            if hasMore {
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { showAllNeeds.toggle() }
                } label: {
                    Text(showAllNeeds ? "See less ∧" : "See more ∨")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Wants（数据来自 API `flexible_breakdown` / avg_monthly_flexible）

    private var wantsSpendingCard: some View {
        let allItems = (viewModel.spendingStats?.flexibleBreakdown ?? [])
            .sorted { $0.avgMonthlyAmount > $1.avgMonthlyAmount }
        let total = viewModel.spendingStats?.avgMonthlyFlexible ?? 0
        let maxAmount = allItems.map(\.avgMonthlyAmount).max() ?? 1
        let visibleItems = showAllWants ? allItems : Array(allItems.prefix(5))
        let hasMore = allItems.count > 5

        return VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
            HStack {
                HStack(spacing: AppSpacing.sm) {
                    Circle().fill(tealColor).frame(width: AppSpacing.sm, height: AppSpacing.sm)
                    Text("Wants")
                        .font(.figureSecondarySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                Text("$\(formattedInt(total))")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
            }

            ForEach(visibleItems) { item in
                categoryRow(
                    emoji: CategoryDisplay.emoji(item.subcategory),
                    name: CategoryDisplay.displayName(item.subcategory),
                    amount: item.avgMonthlyAmount,
                    maxAmount: maxAmount,
                    barColor: tealColor
                )
            }

            if hasMore {
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { showAllWants.toggle() }
                } label: {
                    Text(showAllWants ? "See less ∧" : "See more ∨")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func categoryRow(emoji: String, name: String, amount: Double, maxAmount: Double, barColor: Color) -> some View {
        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            Text(emoji)
                .font(.bodyRegular)
                .frame(width: AppRadius.button)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(name)
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                // Proportional bar below name (use overlay trick to avoid GeometryReader width issues)
                let ratio = maxAmount > 0 ? CGFloat(amount / maxAmount) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.sm / 4)
                        .fill(barColor.opacity(0.08))
                        .frame(maxWidth: .infinity)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: AppRadius.sm / 4)
                            .fill(barColor.opacity(0.35))
                            .frame(width: max(AppSpacing.xs, geo.size.width * ratio))
                    }
                }
                .frame(height: AppSpacing.xs)
            }
            .frame(maxWidth: .infinity)

            Text("$\(formattedInt(amount))")
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Tip Banner

    private var tipBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm + AppSpacing.xs) {
            Text("\u{1F4A1}")
                .font(.bodyRegular)
            Text("Wants spending is where your savings live. In the next steps, we'll show how small reductions here can significantly grow your investments over time.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [AppColors.backgroundSecondary.opacity(0), AppColors.backgroundSecondary], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                Task { await viewModel.loadPlans() }
                viewModel.goToStep(.choosePath)
            } label: {
                Text("Continue")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.backgroundSecondary)
        }
    }

    // MARK: - Helpers

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

}

#Preview {
    BS_SpendingBreakdownView(viewModel: BudgetSetupViewModel())
}
