//
//  OB_ValueScreenView.swift
//  Flamora app
//
//  Onboarding - Step 8: Dynamic Value Screen (based on painPoint)
//

import SwiftUI

struct OB_ValueScreenView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: OB_OnboardingHeader.height)
                    Spacer().frame(height: AppSpacing.sm)

                    switch data.painPoint {
                    case "pain_saving":
                        ValueSavingContent()
                    case "pain_investing":
                        ValueInvestingContent()
                    case "pain_fire":
                        ValueFireContent()
                    default:
                        ValueMoneyTrackingContent()
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.md)
                .padding(.bottom, AppSpacing.tabBarReserve + AppSpacing.xl + AppSpacing.xs) // 为底部固定按钮留出空间
            }

            // 固定在屏幕最下方的 CTA
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [AppColors.shellBg2.opacity(0), AppColors.shellBg2],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: AppRadius.button)

                OB_PrimaryButton(title: "Continue", action: onNext)
            }
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - pain_money_tracking

private struct ValueMoneyTrackingContent: View {
    // Animation phase: 1 = transactions, 2 = donut, 3 = categories
    @State private var phase = 0
    @State private var visibleRows = 0
    @State private var needsExpanded = false
    @State private var wantsExpanded = false

    private let transactions: [(name: String, amount: String)] = [
        ("Target", "$88.60"),
        ("Five Guys", "$22.10"),
        ("Netflix", "$15.99"),
        ("Starbucks", "$6.50"),
        ("Trader Joe's", "$43.50"),
        ("Shell Gas", "$52.30"),
        ("Con Edison", "$96.00"),
        ("Zara", "$125.00"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("We automatically sort\nevery dollar for you")
                .font(.obQuestion)
                .foregroundColor(AppColors.inkPrimary)

            // Animated card area
            VStack(spacing: 0) {
                // Phase 1: Transaction list
                if phase < 2 {
                    VStack(spacing: 0) {
                        ForEach(0..<transactions.count, id: \.self) { index in
                            HStack {
                                Text(transactions[index].name)
                                    .font(.supportingText)
                                    .foregroundColor(AppColors.inkPrimary)
                                Spacer()
                                Text(transactions[index].amount)
                                    .font(.supportingText)
                                    .foregroundColor(AppColors.inkPrimary)
                            }
                            .padding(.vertical, AppSpacing.sm + AppSpacing.xs)
                            .opacity(index < visibleRows ? 1 : 0)
                            .offset(y: index < visibleRows ? 0 : AppSpacing.sm + AppSpacing.xs)
                            .animation(
                                .easeOut(duration: 0.25),
                                value: visibleRows
                            )

                            if index < transactions.count - 1 {
                                Divider().overlay(AppColors.inkBorder.opacity(0.3))
                            }
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.glassCardBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        )
                    )
                }

                // Phase 2 & 3: Donut chart + categories
                if phase >= 2 {
                    VStack(spacing: AppSpacing.md + AppSpacing.sm - AppSpacing.xs) {
                        // Donut chart (Needs 62% / Wants 38%)
                        ZStack {
                            Circle()
                                .trim(from: 0, to: 0.62)
                                .stroke(
                                    AppColors.accentPurple,
                                    style: StrokeStyle(lineWidth: AppSpacing.md, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            Circle()
                                .trim(from: 0.63, to: 1.0)
                                .stroke(
                                    AppColors.accentBlue,
                                    style: StrokeStyle(lineWidth: AppSpacing.md, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: AppSpacing.xs / 2) {
                                Text("TOTAL")
                                    .font(.label)
                                    .foregroundColor(AppColors.textTertiary)
                                    .tracking(1)
                                Text("$3,200")
                                    .font(.detailTitle)
                                    .foregroundColor(AppColors.inkPrimary)
                            }
                        }
                        .frame(width: 130, height: 130)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(phase >= 2 ? 1 : 0.3)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))

                        // Phase 3: Category cards
                        if phase >= 3 {
                            VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                                // Needs card
                                categoryCard(
                                    color: AppColors.accentPurple,
                                    title: "Needs",
                                    total: "$1,984",
                                    isExpanded: needsExpanded,
                                    items: [
                                        ("cart.fill", "Groceries", "$132.10"),
                                        ("bolt.fill", "Utilities", "$96.00"),
                                        ("fuelpump.fill", "Gas", "$52.30"),
                                    ]
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        needsExpanded.toggle()
                                    }
                                }

                                // Wants card
                                categoryCard(
                                    color: AppColors.accentBlue,
                                    title: "Wants",
                                    total: "$1,216",
                                    isExpanded: wantsExpanded,
                                    items: [
                                        ("fork.knife", "Dining", "$28.60"),
                                        ("tv.fill", "Entertainment", "$15.99"),
                                        ("bag.fill", "Shopping", "$125.00"),
                                    ]
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        wantsExpanded.toggle()
                                    }
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.glassCardBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
            }

            // Bottom text
            Text("Flamora connects to your accounts and automatically categorizes every transaction in real-time — so you always know exactly where your money goes.")
                .font(.bodySmall)
                .foregroundColor(AppColors.inkSoft)
                .lineSpacing(4)
        }
        .onAppear { startSequence() }
    }

    // MARK: - Category Card

    @ViewBuilder
    private func categoryCard(
        color: Color,
        title: String,
        total: String,
        isExpanded: Bool,
        items: [(icon: String, category: String, amount: String)],
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onTap) {
                HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                    Circle().fill(color).frame(width: 10, height: 10)
                    Text(title)
                        .font(.supportingText)
                        .foregroundColor(AppColors.inkPrimary)
                    Spacer()
                    Text(total)
                        .font(.cardFigureSecondary)
                        .foregroundColor(AppColors.inkPrimary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, AppSpacing.sm + AppSpacing.xs)
                .padding(.horizontal, AppSpacing.sm + AppSpacing.xs + AppSpacing.xs)
            }
            .buttonStyle(.plain)

            // Expanded detail rows
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(0..<items.count, id: \.self) { i in
                        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                            Image(systemName: items[i].icon)
                                .font(.bodyRegular)
                                .foregroundStyle(AppColors.inkPrimary)
                                .frame(width: 20)
                            Text(items[i].category)
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.inkPrimary)
                            Spacer()
                            Text(items[i].amount)
                                .font(.footnoteSemibold)
                                .foregroundColor(AppColors.inkSoft)
                        }
                        .padding(.vertical, AppSpacing.sm)
                        .padding(.horizontal, AppSpacing.sm + AppSpacing.xs + AppSpacing.xs)

                        if i < items.count - 1 {
                            Divider()
                                .overlay(AppColors.inkBorder.opacity(0.3))
                                .padding(.leading, AppSpacing.md + AppSpacing.md + AppSpacing.xs + AppSpacing.xs + AppSpacing.xs)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .background(AppColors.glassBlockBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Animation Sequence

    private func startSequence() {
        // Phase 1: show transaction rows one by one
        withAnimation { phase = 1 }
        for i in 1...transactions.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                visibleRows = i
            }
        }

        // Phase 2: collapse list → show donut (after ~2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                phase = 2
            }
        }

        // Phase 3: show category cards (after ~3.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = 3
            }
        }
    }
}

#Preview("Money Tracking") {
    ScrollView {
        ValueMoneyTrackingContent()
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
    }
    .background(AppColors.shellBg2)
}

// MARK: - pain_saving

private struct ValueSavingContent: View {
    @State private var showCells = false

    private let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private let completedCount = 9 // JAN-SEP completed

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Small wins build big momentum")
                .font(.obQuestion)
                .foregroundColor(AppColors.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Preview card
            VStack(spacing: AppSpacing.cardGap) {
                HStack {
                    HStack(spacing: AppSpacing.sm) {
                        Text("✦")
                            .font(.label)
                        Text("MONTHLY TRACKING")
                            .font(.label)
                            .tracking(1)
                    }
                    .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("2026")
                        .font(.cardRowMeta)
                        .foregroundColor(AppColors.inkSoft)
                        .padding(.horizontal, AppSpacing.sm + AppSpacing.xs + AppSpacing.xs)
                        .padding(.vertical, AppSpacing.xs)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(AppColors.inkBorder, lineWidth: 1)
                        )
                }

                // 4x3 month grid
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm + AppSpacing.xs), count: 4)
                LazyVGrid(columns: columns, spacing: AppSpacing.sm + AppSpacing.xs) {
                    ForEach(0..<12, id: \.self) { index in
                        monthCell(index: index)
                            .opacity(showCells ? 1 : 0)
                            .scaleEffect(showCells ? 1 : 0.8)
                            .animation(
                                .spring(response: 0.3, dampingFraction: 0.7)
                                .delay(Double(index) * 0.06),
                                value: showCells
                            )
                    }
                }

                Divider().overlay(AppColors.inkBorder)

                // Bottom stats
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("✦")
                                .font(.miniLabel)
                            Text("SAVING RATE")
                                .font(.miniLabel)
                        }
                        .foregroundColor(AppColors.textTertiary)
                        Text("20%")
                            .font(.h4)
                            .foregroundColor(AppColors.inkPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("✦")
                                .font(.miniLabel)
                            Text("TARGET SAVING")
                                .font(.miniLabel)
                        }
                        .foregroundColor(AppColors.textTertiary)
                        Text("$200")
                            .font(.h4)
                            .foregroundColor(AppColors.inkPrimary)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

            Text("Consistency beats perfection. Track your monthly milestones throughout 2026.")
                .font(.bodySmall)
                .foregroundColor(AppColors.inkSoft)
                .lineSpacing(4)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showCells = true
            }
        }
    }

    @ViewBuilder
    private func monthCell(index: Int) -> some View {
        let isCompleted = index < completedCount
        // Vary gradient angle per cell for visual layering
        let angle = Angle.degrees(Double(index) * 15 + 225) // 225°-based, rotates per cell
        let startPt = UnitPoint(x: 0.5 + 0.5 * cos(angle.radians), y: 0.5 + 0.5 * sin(angle.radians))
        let endPt = UnitPoint(x: 0.5 - 0.5 * cos(angle.radians), y: 0.5 - 0.5 * sin(angle.radians))

        VStack(spacing: AppSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(
                        isCompleted
                            ? AnyShapeStyle(LinearGradient(
                                colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
                                startPoint: startPt,
                                endPoint: endPt
                            ))
                            : AnyShapeStyle(AppColors.glassBlockBg)
                    )
                    .frame(height: 52)

                Image(systemName: isCompleted ? "checkmark" : "plus")
                    .font(isCompleted ? .bodyRegular : .h4)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? AppColors.inkPrimary : AppColors.textTertiary)
            }

            Text(months[index])
                .font(.miniLabel)
                .foregroundColor(AppColors.textTertiary)
        }
    }
}

#Preview("Saving") {
    ScrollView {
        ValueSavingContent()
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
    }
    .background(AppColors.shellBg2)
}

// MARK: - pain_investing

private struct ValueInvestingContent: View {
    @State private var drawProgress: CGFloat = 0
    @State private var showCostBadge = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("It's not about how much\nIt's about how early")
                .font(.obQuestion)
                .foregroundColor(AppColors.inkPrimary)

            // Preview card
            VStack(spacing: AppSpacing.cardGap) {
                // Chart with cost-of-waiting badge overlay
                ZStack(alignment: .topTrailing) {
                    CompoundGrowthChart(drawProgress: drawProgress)
                        .frame(height: 160)

                    // Cost of waiting badge — slides in from right after curves finish
                    VStack(spacing: AppSpacing.xs / 2) {
                        Text("COST OF WAITING")
                            .font(.miniLabel)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.5)
                        Text("$213,000")
                            .font(.bodySemibold)
                            .foregroundColor(AppColors.inkPrimary)
                    }
                    .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.glassBlockBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .stroke(AppColors.inkBorder, lineWidth: 1)
                    )
                    .opacity(showCostBadge ? 1 : 0)
                    .offset(x: showCostBadge ? 0 : AppSpacing.md + AppSpacing.xs)
                }

                Text("Investing $300/month")
                    .font(.caption)
                    .foregroundColor(AppColors.inkSoft)
                    .frame(maxWidth: .infinity)

                Divider().overlay(AppColors.inkBorder)

                // Legend
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                            Circle().fill(AppColors.gradientStart).frame(width: 8, height: 8)
                            Text("Start now")
                                .font(.caption)
                                .foregroundColor(AppColors.inkSoft)
                        }
                        Text("$549k")
                            .font(.detailTitle)
                            .foregroundColor(AppColors.inkPrimary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                            Circle().fill(AppColors.textTertiary).frame(width: 8, height: 8)
                            Text("Wait 5 yrs")
                                .font(.caption)
                                .foregroundColor(AppColors.inkSoft)
                        }
                        Text("$336k")
                            .font(.detailTitle)
                            .foregroundColor(AppColors.inkPrimary)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

            Text("Even small contributions grow dramatically with time. Flamora helps you find that extra $100-300/month hiding in your spending.")
                .font(.bodySmall)
                .foregroundColor(AppColors.inkSoft)
                .lineSpacing(4)
        }
        .onAppear {
            // Draw curves (0.3s delay, 1.5s duration → finishes at ~1.8s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    drawProgress = 1.0
                }
            }
            // Show cost badge after curves finish + 0.5s pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showCostBadge = true
                }
            }
        }
    }
}

// Compound interest growth chart: FV = PMT × ((1+r)^n - 1) / r
private struct CompoundGrowthChart: View {
    let drawProgress: CGFloat

    // PMT = $300/month, annual rate = 9%, monthly r = 0.0075
    private static func futureValue(years: Int) -> Double {
        let pmt = 300.0
        let r = 0.09 / 12.0
        let n = Double(years * 12)
        guard n > 0 else { return 0 }
        return pmt * (pow(1 + r, n) - 1) / r
    }

    // Pre-computed: start now → 31 pts, wait 5 → 31 pts
    private static let startNowData: [Double] = (0...30).map { futureValue(years: $0) }
    private static let waitData: [Double] = (0...30).map { $0 <= 5 ? 0 : futureValue(years: $0 - 5) }
    private static let maxVal: Double = futureValue(years: 30) // ~$549k

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let chartH = h - 14 // room for x-axis labels
            let startPts = Self.startNowData.enumerated().map { i, v in
                CGPoint(x: CGFloat(i) / 30.0 * w, y: chartH - CGFloat(v / Self.maxVal) * chartH)
            }
            let waitPts = Self.waitData.enumerated().map { i, v in
                CGPoint(x: CGFloat(i) / 30.0 * w, y: chartH - CGFloat(v / Self.maxVal) * chartH)
            }

            ZStack {
                // Fill under "Start now" curve
                fillPath(points: startPts, bottomY: chartH)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.gradientEnd.opacity(0.15),
                                AppColors.gradientMiddle.opacity(0.08),
                                AppColors.gradientStart.opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // "Wait 5 yrs" curve (gray)
                strokePath(points: waitPts)
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        AppColors.textTertiary,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )

                // "Start now" curve (yellow → pink → purple)
                strokePath(points: startPts)
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )

                // Endpoint dots (appear after curve is drawn)
                if drawProgress >= 1.0, let startEnd = startPts.last, let waitEnd = waitPts.last {
                    // "Start now" endpoint — gradient dot
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 8, height: 8)
                        .position(startEnd)

                    // "Wait 5 yrs" endpoint — gray dot
                    Circle()
                        .fill(AppColors.textTertiary)
                        .frame(width: 8, height: 8)
                        .position(waitEnd)
                }

                // Y-axis label
                Text("$550k")
                    .font(.miniLabel)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // X-axis labels
                HStack {
                    Text("Year 0")
                    Spacer()
                    Text("Year 15")
                    Spacer()
                    Text("Year 30")
                }
                .font(.miniLabel)
                .foregroundColor(AppColors.textTertiary)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    private func strokePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
        }
    }

    private func fillPath(points: [CGPoint], bottomY: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: bottomY))
            path.addLine(to: first)
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
            path.addLine(to: CGPoint(x: last.x, y: bottomY))
            path.closeSubpath()
        }
    }
}

#Preview("Investing") {
    ScrollView {
        ValueInvestingContent()
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
    }
    .background(AppColors.shellBg2)
}

// MARK: - pain_fire

private struct ValueFireContent: View {
    // Tracks which step is currently "lit up" (0 = none lit)
    @State private var litStep = 0

    private let steps: [(icon: String, text: String)] = [
        ("scope", "Set your goal"),
        ("link", "Connect accounts"),
        ("square.grid.2x2", "Get your personalized plan"),
        ("arrow.triangle.2.circlepath", "Auto-track progress"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("We'll guide you every step of the way")
                .font(.obQuestion)
                .foregroundColor(AppColors.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer().frame(height: AppSpacing.sm)

            // Timeline — all 4 steps visible from start, dim until lit
            VStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    timelineRow(index: index, isLit: index < litStep)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: litStep)

            Spacer().frame(height: AppSpacing.md)

            Text("No spreadsheets. No guesswork. Just a system that keeps you on track — automatically.")
                .font(.bodySmall)
                .foregroundColor(AppColors.inkSoft)
                .lineSpacing(4)
        }
        .onAppear {
            for i in 1...steps.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                    litStep = i
                }
            }
        }
    }

    @ViewBuilder
    private func timelineRow(index: Int, isLit: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                // Left: circle icon
                ZStack {
                    Circle()
                        .fill(
                            isLit
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
                                    startPoint: .bottomLeading,
                                    endPoint: .topTrailing
                                ))
                                : AnyShapeStyle(AppColors.glassBlockBg)
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: steps[index].icon)
                        .font(.chromeIconMedium)
                        .foregroundColor(isLit ? AppColors.inkPrimary : AppColors.textTertiary)
                }

                // Right: text centered to icon
                Text(steps[index].text)
                    .font(isLit ? .bodySemibold : .bodyRegular)
                    .foregroundColor(isLit ? AppColors.inkPrimary : AppColors.textTertiary)

                Spacer()
            }

            // Connector line between steps — centered under 48pt icon
            if index < steps.count - 1 {
                Rectangle()
                    .fill(AppColors.inkBorder)
                    .frame(width: 1, height: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, AppSpacing.lg)
            }
        }
    }
}

#Preview("FIRE") {
    ScrollView {
        ValueFireContent()
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)
    }
    .background(AppColors.shellBg2)
}

#Preview("Value Screen (full)") {
    ZStack {
        LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        OB_ValueScreenView(data: OnboardingData(), onNext: {}, onBack: {})
        VStack {
            OB_OnboardingHeader(onBack: {}, current: 5, total: 10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
