//
//  BS_SpendingBreakdownView.swift
//  Flamora app
//
//  Budget Setup — Step 3: Where Your Money Goes
//  V2: Donut chart (Fixed vs Flexible), category detail cards, tip banner
//

import SwiftUI

struct BS_SpendingBreakdownView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @State private var selectedSegment: Segment? = nil
    @State private var showAllFixed = false
    @State private var showAllFlexible = false

    private let gradientColors = [Color(hex: "F5C842"), Color(hex: "E88BC4")]
    private let purpleColor = Color(hex: "C084FC")
    private let tealColor = Color(hex: "34D399")

    private enum Segment {
        case fixed, flexible
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0A0A0C").ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer().frame(height: 60)

                    headerSection
                        .padding(.horizontal, 26)

                    donutChartCard
                        .padding(.horizontal, 26)

                    fixedExpensesCard
                        .padding(.horizontal, 26)

                    flexibleSpendingCard
                        .padding(.horizontal, 26)

                    tipBanner
                        .padding(.horizontal, 26)

                    Spacer().frame(height: 140)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 16)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { viewModel.goBack() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "ABABAB"))
            }
            .padding(.bottom, 8)

            Text("Your Spending Breakdown")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "F2F0ED"))

            Text("We categorized your spending into fixed and flexible expenses.")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "ABABAB"))
                .lineSpacing(3)
        }
    }

    // MARK: - Donut Chart Card

    private var donutChartCard: some View {
        let stats = viewModel.spendingStats
        let fixed = stats?.avgMonthlyFixed ?? 0
        let flexible = stats?.avgMonthlyFlexible ?? 0
        let total = fixed + flexible
        let fixedFrac = total > 0 ? fixed / total : 0.5

        // Full 360° ring with lineCap: .round — rounded caps on each segment's
        // endpoints naturally create a visual gap at the junctions (Apple Fitness style).
        let fixedFrac2 = fixedFrac  // capture for use in closures below

        let centerLabel: String = {
            switch selectedSegment {
            case .fixed:    return "FIXED EXPENSES"
            case .flexible: return "FLEXIBLE SPENDING"
            case nil:       return "MONTHLY AVG"
            }
        }()
        let centerAmount: Double = {
            switch selectedSegment {
            case .fixed:    return fixed
            case .flexible: return flexible
            case nil:       return total
            }
        }()

        return VStack(spacing: 20) {
            ZStack {
                // Background track (full ring, very subtle)
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 20)
                    .frame(width: 170, height: 170)

                // Fixed arc (purple) — rounded caps
                Circle()
                    .trim(from: 0, to: fixedFrac2)
                    .stroke(
                        purpleColor.opacity(selectedSegment == .flexible ? 0.2 : 1),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))

                // Flexible arc (teal) — rounded caps
                Circle()
                    .trim(from: fixedFrac2, to: 1.0)
                    .stroke(
                        tealColor.opacity(selectedSegment == .fixed ? 0.2 : 1),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))

                // Center text: label above, amount below
                VStack(spacing: 4) {
                    Text(centerLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("$\(formattedInt(centerAmount))")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "F2F0ED"))
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
            HStack(spacing: 24) {
                legendButton(color: purpleColor, label: "Fixed",    amount: fixed,    segment: .fixed)
                legendButton(color: tealColor,   label: "Flexible", amount: flexible, segment: .flexible)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "ABABAB"))
                    Text("$\(formattedInt(amount))")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "F2F0ED"))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fixed Expenses Card

    private var fixedExpensesCard: some View {
        let allItems = (viewModel.spendingStats?.fixedExpenses ?? [])
            .sorted { $0.avgMonthlyAmount > $1.avgMonthlyAmount }
        let total = viewModel.spendingStats?.avgMonthlyFixed ?? 0
        let maxAmount = allItems.map(\.avgMonthlyAmount).max() ?? 1
        let visibleItems = showAllFixed ? allItems : Array(allItems.prefix(4))
        let hasMore = allItems.count > 4

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(purpleColor).frame(width: 8, height: 8)
                    Text("Fixed Expenses")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "F2F0ED"))
                }
                Spacer()
                Text("$\(formattedInt(total))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "F2F0ED"))
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
                    withAnimation(.easeOut(duration: 0.3)) { showAllFixed.toggle() }
                } label: {
                    Text(showAllFixed ? "See less ∧" : "See more ∨")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "ABABAB"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Flexible Spending Card

    private var flexibleSpendingCard: some View {
        let allItems = (viewModel.spendingStats?.flexibleBreakdown ?? [])
            .sorted { $0.avgMonthlyAmount > $1.avgMonthlyAmount }
        let total = viewModel.spendingStats?.avgMonthlyFlexible ?? 0
        let maxAmount = allItems.map(\.avgMonthlyAmount).max() ?? 1
        let visibleItems = showAllFlexible ? allItems : Array(allItems.prefix(5))
        let hasMore = allItems.count > 5

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(tealColor).frame(width: 8, height: 8)
                    Text("Flexible Spending")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "F2F0ED"))
                }
                Spacer()
                Text("$\(formattedInt(total))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "F2F0ED"))
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
                    withAnimation(.easeOut(duration: 0.3)) { showAllFlexible.toggle() }
                } label: {
                    Text(showAllFlexible ? "See less ∧" : "See more ∨")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "ABABAB"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func categoryRow(emoji: String, name: String, amount: Double, maxAmount: Double, barColor: Color) -> some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 16))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "F2F0ED"))
                    .lineLimit(1)

                // Proportional bar below name (use overlay trick to avoid GeometryReader width issues)
                let ratio = maxAmount > 0 ? CGFloat(amount / maxAmount) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor.opacity(0.08))
                        .frame(maxWidth: .infinity)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor.opacity(0.35))
                            .frame(width: max(4, geo.size.width * ratio))
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)

            Text("$\(formattedInt(amount))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "F2F0ED"))
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Tip Banner

    private var tipBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\u{1F4A1}")
                .font(.system(size: 16))
            Text("Flexible spending is where your savings live. In the next steps, we'll show how small reductions here can significantly grow your investments over time.")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "ABABAB"))
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: "0A0A0C").opacity(0), Color(hex: "0A0A0C")], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)

            Button {
                Task { await viewModel.loadPlans() }
                viewModel.goToStep(.choosePath)
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)
            .background(Color(hex: "0A0A0C"))
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
