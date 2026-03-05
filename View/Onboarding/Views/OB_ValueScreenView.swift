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
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    OB_BackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                OB_PersonalizeProgress(currentStep: 5, totalSteps: 5)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
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
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
                }

                // CTA
                OB_PrimaryButton(title: "Continue", action: onNext)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
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
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 32)

            Text("We automatically sort\nevery dollar for you")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)

            // Animated card area
            VStack(spacing: 0) {
                // Phase 1: Transaction list
                if phase < 2 {
                    VStack(spacing: 0) {
                        ForEach(0..<transactions.count, id: \.self) { index in
                            HStack {
                                Text(transactions[index].name)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text(transactions[index].amount)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .padding(.vertical, 10)
                            .opacity(index < visibleRows ? 1 : 0)
                            .offset(y: index < visibleRows ? 0 : 12)
                            .animation(
                                .easeOut(duration: 0.25),
                                value: visibleRows
                            )

                            if index < transactions.count - 1 {
                                Divider().overlay(AppColors.borderDefault.opacity(0.3))
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(12)
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        )
                    )
                }

                // Phase 2 & 3: Donut chart + categories
                if phase >= 2 {
                    VStack(spacing: 20) {
                        // Donut chart
                        ZStack {
                            Circle()
                                .trim(from: 0, to: 0.62)
                                .stroke(
                                    AppColors.gradientEnd,
                                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            Circle()
                                .trim(from: 0.63, to: 1.0)
                                .stroke(
                                    AppColors.gradientStart,
                                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 2) {
                                Text("TOTAL")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(AppColors.textTertiary)
                                    .tracking(1)
                                Text("$3,200")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                        .frame(width: 130, height: 130)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(phase >= 2 ? 1 : 0.3)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))

                        // Phase 3: Category cards
                        if phase >= 3 {
                            VStack(spacing: 10) {
                                // Needs card
                                categoryCard(
                                    color: AppColors.gradientEnd,
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
                                    color: AppColors.gradientStart,
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
                    .padding(20)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(12)
                }
            }

            // Bottom text
            Text("Flamora connects to your accounts and automatically categorizes every transaction in real-time — so you always know exactly where your money goes.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
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
                HStack(spacing: 10) {
                    Circle().fill(color).frame(width: 10, height: 10)
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(total)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)

            // Expanded detail rows
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(0..<items.count, id: \.self) { i in
                        HStack(spacing: 10) {
                            Image(systemName: items[i].icon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 20)
                            Text(items[i].category)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(items[i].amount)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)

                        if i < items.count - 1 {
                            Divider()
                                .overlay(AppColors.borderDefault.opacity(0.3))
                                .padding(.leading, 44)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColors.backgroundCardHover)
        .cornerRadius(10)
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

// MARK: - pain_saving

private struct ValueSavingContent: View {
    @State private var showCells = false

    private let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private let completedCount = 9 // JAN-SEP completed

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 32)

            Text("Small wins build\nbig momentum.")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)

            // Preview card
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 6) {
                        Text("✦")
                            .font(.system(size: 10))
                        Text("MONTHLY TRACKING")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1)
                    }
                    .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("2026")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppColors.borderDefault, lineWidth: 1)
                        )
                }

                // 4x3 month grid
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
                LazyVGrid(columns: columns, spacing: 10) {
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

                Divider().overlay(AppColors.borderDefault)

                // Bottom stats
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("✦")
                                .font(.system(size: 8))
                            Text("SAVING RATE")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textTertiary)
                        Text("20%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("✦")
                                .font(.system(size: 8))
                            Text("TARGET SAVING")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textTertiary)
                        Text("$200")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .padding(20)
            .background(AppColors.backgroundCard)
            .cornerRadius(16)

            Text("Consistency beats perfection. Track your monthly milestones throughout 2026.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
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

        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isCompleted
                            ? AnyShapeStyle(LinearGradient(
                                colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
                                startPoint: startPt,
                                endPoint: endPt
                            ))
                            : AnyShapeStyle(AppColors.backgroundCardHover)
                    )
                    .frame(height: 52)

                Image(systemName: isCompleted ? "checkmark" : "plus")
                    .font(.system(size: isCompleted ? 16 : 18, weight: .medium))
                    .foregroundColor(isCompleted ? .white : AppColors.textTertiary)
            }

            Text(months[index])
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
        }
    }
}

// MARK: - pain_investing

private struct ValueInvestingContent: View {
    @State private var drawProgress: CGFloat = 0
    @State private var showCostBadge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 32)

            Text("It's not about how much.\nIt's about how early.")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)

            // Preview card
            VStack(spacing: 16) {
                // Chart with cost-of-waiting badge overlay
                ZStack(alignment: .topTrailing) {
                    CompoundGrowthChart(drawProgress: drawProgress)
                        .frame(height: 160)

                    // Cost of waiting badge — slides in from right after curves finish
                    VStack(spacing: 2) {
                        Text("COST OF WAITING")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.5)
                        Text("$213,000")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.backgroundCardHover)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.borderDefault, lineWidth: 1)
                    )
                    .opacity(showCostBadge ? 1 : 0)
                    .offset(x: showCostBadge ? 0 : 20)
                }

                Text("Investing $300/month")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)

                Divider().overlay(AppColors.borderDefault)

                // Legend
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(AppColors.gradientStart).frame(width: 8, height: 8)
                            Text("Start now")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Text("$549k")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(AppColors.textTertiary).frame(width: 8, height: 8)
                            Text("Wait 5 yrs")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Text("$336k")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .padding(20)
            .background(AppColors.backgroundCard)
            .cornerRadius(16)

            Text("Even small contributions grow dramatically with time. Flamora helps you find that extra $100-300/month hiding in your spending.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
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
                    .font(.system(size: 9))
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
                .font(.system(size: 9))
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
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 32)

            Text("We'll guide you every\nstep of the way")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)

            Spacer().frame(height: 8)

            // Timeline — all 4 steps visible from start, dim until lit
            VStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    timelineRow(index: index, isLit: index < litStep)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: litStep)

            Spacer().frame(height: 16)

            Text("No spreadsheets. No guesswork. Just a system that keeps you on track — automatically.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
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
            HStack(alignment: .center, spacing: 16) {
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
                                : AnyShapeStyle(AppColors.backgroundCardHover)
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: steps[index].icon)
                        .font(.system(size: 18))
                        .foregroundColor(isLit ? .white : AppColors.textTertiary)
                }

                // Right: text centered to icon
                Text(steps[index].text)
                    .font(.system(size: 16, weight: isLit ? .semibold : .regular))
                    .foregroundColor(isLit ? AppColors.textPrimary : AppColors.textTertiary)

                Spacer()
            }

            // Connector line between steps — centered under 48pt icon
            if index < steps.count - 1 {
                Rectangle()
                    .fill(AppColors.borderDefault)
                    .frame(width: 1, height: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
            }
        }
    }
}

#Preview {
    OB_ValueScreenView(data: OnboardingData(), onNext: {}, onBack: {})
        .background(AppBackgroundView())
}
