//
//  OB_ChallengeFlowViews.swift
//  Flamora app
//
//  Personalized UX reveal pages shown after Financial Challenge selection.
//  Dispatched from OnboardingContainerView based on data.primaryChallenge key.
//

import SwiftUI

// MARK: - View 1 · "no_visibility" → Transactions collapse into Needs/Wants donut

struct OB_ChallengeNoVisibilityView: View {
    var onNext: () -> Void

    @State private var showTransactions = false
    @State private var collapsed = false
    @State private var needsTrim: CGFloat = 0
    @State private var wantsTrim: CGFloat = 0
    @State private var showCenter = false
    @State private var showLegend = false
    @State private var sheetCategory = ""
    @State private var showSheet = false

    private let txns: [(name: String, amount: String)] = [
        ("Grocery Store",  "$88.60"),
        ("Ride Share",     "$22.10"),
        ("Subscription",   "$15.99"),
        ("Dining Out",     "$43.50"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 48)

                    Text("We automatically sort\nevery dollar for you")
                        .font(.obQuestion)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: AppSpacing.lg)

                    // Main card
                    VStack(spacing: 16) {
                        HStack {
                            Text("RECENT TRANSACTIONS")
                                .font(.obStepLabel)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(0.8)
                            Spacer()
                        }

                        if !collapsed {
                            transactionListView
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.combined(with: .offset(y: -16))
                                ))
                        }

                        if collapsed {
                            donutSectionView
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.93, anchor: .center)),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                    )
                    .animation(.spring(response: 0.55, dampingFraction: 0.85), value: collapsed)

                    Spacer().frame(height: AppSpacing.lg)

                    Text("Flamora connects to your accounts and automatically categorizes every transaction in real-time — so you always know exactly where your money goes.")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppSpacing.sm)

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            stickyCtaView(action: onNext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showSheet) {
            NeedsWantsCategorySheet(category: sheetCategory)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear { startAnimation() }
    }

    // MARK: Transaction list

    private var transactionListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(txns.enumerated()), id: \.offset) { i, t in
                HStack {
                    Text(t.name)
                        .font(.bodySmall)
                        .foregroundColor(.white)
                    Spacer()
                    Text(t.amount)
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.vertical, 9)
                .opacity(showTransactions ? 1 : 0)
                .offset(y: showTransactions ? 0 : 8)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8).delay(Double(i) * 0.12),
                    value: showTransactions
                )

                if i < txns.count - 1 {
                    Rectangle()
                        .fill(AppColors.surfaceBorder)
                        .frame(height: 0.5)
                }
            }

            // Down chevron hint
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(AppColors.surfaceElevated)
                        .frame(width: 28, height: 28)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            }
            .padding(.top, 8)
            .opacity(showTransactions ? 1 : 0)
            .animation(.easeOut.delay(0.55), value: showTransactions)
        }
    }

    // MARK: Donut section

    private var donutSectionView: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background track
                Circle()
                    .stroke(AppColors.surfaceInput, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .frame(width: 150, height: 150)

                // Wants arc (blue) — positioned after needs at 0.62
                Circle()
                    .trim(from: 0.62, to: 0.62 + wantsTrim)
                    .stroke(AppColors.accentBlue, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 150, height: 150)

                // Needs arc (purple) — from 12 o'clock clockwise
                Circle()
                    .trim(from: 0, to: needsTrim)
                    .stroke(AppColors.accentPurple, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 150, height: 150)

                // Center label
                VStack(spacing: 2) {
                    Text("TOTAL")
                        .font(.obStepLabel)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(0.8)
                    Text("$3.2k")
                        .font(.h2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .opacity(showCenter ? 1 : 0)
                .scaleEffect(showCenter ? 1 : 0.8)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showCenter)
            }
            .frame(width: 150, height: 150)

            // Legend
            HStack(spacing: 0) {
                legendButton(color: AppColors.accentPurple, label: "Needs",  amount: "$1,984", key: "needs")
                Rectangle()
                    .fill(AppColors.surfaceBorder)
                    .frame(width: 0.75, height: 44)
                    .padding(.horizontal, 12)
                legendButton(color: AppColors.accentBlue,   label: "Wants",  amount: "$1,216", key: "wants")
            }
            .opacity(showLegend ? 1 : 0)
            .offset(y: showLegend ? 0 : 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showLegend)
        }
    }

    private func legendButton(color: Color, label: String, amount: String, key: String) -> some View {
        Button {
            sheetCategory = key
            showSheet = true
        } label: {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                    Text(amount)
                        .font(.h4)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Animation

    private func startAnimation() {
        withAnimation { showTransactions = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.4)) { collapsed = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.9) {
            withAnimation(.easeInOut(duration: 0.9)) { needsTrim = 0.62 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeInOut(duration: 0.55)) { wantsTrim = 0.37 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) {
            showCenter = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            showLegend = true
        }
    }
}

// MARK: - View 2 · "not_saving" → Monthly tracking grid lights up

struct OB_ChallengeNotSavingView: View {
    var onNext: () -> Void

    private let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private let completedCount = 9  // Jan–Sep filled

    @State private var litCount = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 48)

                    Text("Small wins build\nbig momentum.")
                        .font(.obQuestion)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: AppSpacing.lg)

                    // Card
                    VStack(spacing: 16) {
                        // Header
                        HStack {
                            Circle()
                                .fill(AppColors.accentPurple)
                                .frame(width: 6, height: 6)
                            Text("MONTHLY TRACKING")
                                .font(.obStepLabel)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(0.8)
                            Spacer()
                            Text("2026")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                                )
                        }

                        // 4-column grid
                        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
                        LazyVGrid(columns: cols, spacing: 8) {
                            ForEach(Array(months.enumerated()), id: \.offset) { i, month in
                                MonthCell(
                                    month: month,
                                    isCompleted: i < completedCount,
                                    isLit: i < litCount
                                )
                            }
                        }

                        // Stats row
                        HStack(spacing: 0) {
                            statColumn(dotColor: AppColors.accentPurple,
                                       label: "SAVING RATE", value: "20%")
                            Rectangle()
                                .fill(AppColors.surfaceBorder)
                                .frame(width: 0.75)
                                .padding(.horizontal, 16)
                            statColumn(dotColor: AppColors.accentBlue,
                                       label: "TARGET SAVING", value: "$200")
                        }
                        .padding(.top, 4)
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                    )

                    Spacer().frame(height: AppSpacing.lg)

                    Text("Consistency beats perfection. Track your monthly milestones throughout 2026.")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            stickyCtaView(action: onNext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { startAnimation() }
    }

    private func statColumn(dotColor: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(dotColor).frame(width: 6, height: 6)
                Text(label)
                    .font(.obStepLabel)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(0.8)
            }
            Text(value)
                .font(.h2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startAnimation() {
        for i in 0..<completedCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.18) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
                    litCount = i + 1
                }
            }
        }
    }
}

// MARK: - View 3 · "too_little_to_invest" → Rising investment growth curve

struct OB_ChallengeTooLittleToInvestView: View {
    var onNext: () -> Void

    @State private var startNowProgress: CGFloat = 0
    @State private var waitProgress: CGFloat = 0
    @State private var showCostLabel = false
    @State private var showStats = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 48)

                    Text("It's not about how much.\nIt's about how early.")
                        .font(.obQuestion)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: AppSpacing.lg)

                    // Card
                    VStack(spacing: 12) {
                        // Chart
                        ZStack(alignment: .topLeading) {
                            GeometryReader { geo in
                                let w = geo.size.width
                                let h = geo.size.height

                                ZStack(alignment: .topLeading) {
                                    // Area fill under "start now" (static, subtle)
                                    StartNowAreaFill()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppColors.accentPurple.opacity(0.18),
                                                    Color.clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .opacity(startNowProgress > 0.3 ? startNowProgress : 0)

                                    // "Wait 5 yrs" dashed line (gray)
                                    WaitFiveYrsGrowthPath()
                                        .trim(from: 0, to: waitProgress)
                                        .stroke(
                                            AppColors.textTertiary.opacity(0.7),
                                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3])
                                        )

                                    // "Start now" gradient line
                                    StartNowGrowthPath()
                                        .trim(from: 0, to: startNowProgress)
                                        .stroke(
                                            LinearGradient(
                                                colors: AppColors.gradientFire,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                        )

                                    // End-point dots
                                    if startNowProgress > 0.95 {
                                        Circle()
                                            .fill(AppColors.accentPurple)
                                            .frame(width: 7, height: 7)
                                            .offset(x: w - 4, y: h * 0.045 - 4)
                                            .transition(.opacity.combined(with: .scale(scale: 0.3)))
                                    }
                                    if waitProgress > 0.95 {
                                        Circle()
                                            .fill(AppColors.textTertiary)
                                            .frame(width: 7, height: 7)
                                            .offset(x: w - 4, y: h * 0.285 - 4)
                                            .transition(.opacity.combined(with: .scale(scale: 0.3)))
                                    }
                                }
                                .frame(width: w, height: h)
                            }
                            .frame(height: 160)

                            // Y-axis label
                            Text("$400k")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .offset(x: 0, y: 0)

                            // Cost of waiting label
                            if showCostLabel {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("COST OF WAITING")
                                        .font(.obStepLabel)
                                        .foregroundColor(AppColors.textTertiary)
                                        .tracking(0.5)
                                    Text("$96,000")
                                        .font(.h4)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(.top, 8)
                                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                            }
                        }

                        // X-axis labels
                        HStack {
                            Text("Year 0")
                            Spacer()
                            Text("Year 15")
                            Spacer()
                            Text("Year 30")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)

                        // Caption
                        Text("Investing $300/month")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Stats
                        HStack(spacing: AppSpacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle().fill(AppColors.accentPurple).frame(width: 8, height: 8)
                                    Text("Start now")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Text("$382k")
                                    .font(.h3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle().fill(AppColors.textTertiary).frame(width: 8, height: 8)
                                    Text("Wait 5 yrs")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Text("$286k")
                                    .font(.h3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(showStats ? 1 : 0)
                        .offset(y: showStats ? 0 : 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showStats)
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                    )

                    Spacer().frame(height: AppSpacing.lg)

                    Text("Even small contributions grow dramatically with time. Flamora helps you find that extra $100–300/month hiding in your spending.")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            stickyCtaView(action: onNext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 1.7)) {
                startNowProgress = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 1.4)) {
                waitProgress = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.spring(response: 0.5)) {
                showCostLabel = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            showStats = true
        }
    }
}

// MARK: - View 4 · "retire_early_confused" → 4-step roadmap lights up sequentially

struct OB_ChallengeRetireEarlyView: View {
    var onNext: () -> Void

    @State private var headerVisible = false
    @State private var litCount = 0
    @State private var footerVisible = false

    private let steps: [(icon: String, label: String)] = [
        ("scope",             "Set your goal"),
        ("link",              "Connect accounts"),
        ("squares.grid.2x2", "Get your personalized plan"),
        ("location.north",   "Auto-track progress"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 52)

                Text("We'll guide you\nevery step of the way")
                    .font(.obQuestion)
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 16)

                Spacer().frame(height: 40)

                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        RetireEarlyStepRow(
                            icon: step.icon,
                            label: step.label,
                            isLit: index < litCount,
                            showConnector: index < steps.count - 1,
                            connectorLit: index + 1 < litCount
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                Spacer().frame(height: 32)

                Text("No spreadsheets. No guesswork. Just a system that keeps you on track — automatically.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .opacity(footerVisible ? 1 : 0)

                Spacer()

                Button(action: onNext) {
                    Text("Continue")
                        .font(.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xxl)
                .opacity(footerVisible ? 1 : 0)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        withAnimation(.easeOut(duration: 0.45)) { headerVisible = true }

        // Light up nodes one by one
        let delays: [Double] = [0.3, 0.9, 1.5, 2.1]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.68)) {
                    litCount = i + 1
                }
            }
        }
        withAnimation(.easeOut(duration: 0.4).delay(2.5)) { footerVisible = true }
    }
}

// MARK: - Private Helpers

// Sticky CTA shared across all 4 challenge views
private func stickyCtaView(action: @escaping () -> Void) -> some View {
    VStack(spacing: 0) {
        LinearGradient(
            colors: [Color.black.opacity(0), Color.black],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 32)

        Button(action: action) {
            Text("Continue")
                .font(.bodyRegular)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.bottom, AppSpacing.xxl)
        .background(Color.black)
    }
}

// Month cell for the tracking grid
private struct MonthCell: View {
    let month: String
    let isCompleted: Bool
    let isLit: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Base dark background
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surfaceElevated)

                // Gradient overlay fades in when lit
                if isLit {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .transition(.opacity)
                }

                // Checkmark bounces in when lit
                if isLit {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale(scale: 0.2, anchor: .center).combined(with: .opacity))
                } else if !isCompleted {
                    Text("+")
                        .font(.system(size: 16, weight: .ultraLight))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(height: 64)

            Text(month)
                .font(.obStepLabel)
                .foregroundColor(isLit ? AppColors.textSecondary : AppColors.textTertiary)
                .tracking(0.4)
                .animation(.easeOut(duration: 0.2), value: isLit)
        }
    }
}

// Step row for retire-early view
private struct RetireEarlyStepRow: View {
    let icon: String
    let label: String
    let isLit: Bool
    let showConnector: Bool
    let connectorLit: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 0) {
                ZStack {
                    if isLit {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: AppColors.gradientFire,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .transition(.opacity)
                    } else {
                        Circle()
                            .fill(AppColors.surfaceElevated)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Circle().stroke(AppColors.borderDefault, lineWidth: 1)
                            )
                            .transition(.opacity)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isLit ? .black : AppColors.textTertiary)
                        .animation(.easeOut(duration: 0.2), value: isLit)
                }
                .scaleEffect(isLit ? 1.0 : 0.88)
                .animation(.spring(response: 0.4, dampingFraction: 0.68), value: isLit)

                if showConnector {
                    Rectangle()
                        .fill(connectorLit
                              ? LinearGradient(colors: AppColors.gradientFire, startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [AppColors.borderDefault], startPoint: .top, endPoint: .bottom))
                        .frame(width: 1.5, height: 32)
                        .animation(.easeInOut(duration: 0.4), value: connectorLit)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.h4)
                    .foregroundColor(isLit ? .white : AppColors.textSecondary)
                    .padding(.top, 14)
                    .animation(.easeOut(duration: 0.25), value: isLit)
            }

            Spacer()
        }
    }
}

// MARK: - Growth Path Shapes (for investment chart)

private struct StartNowGrowthPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let maxVal: Double = 400_000
        let pmt: Double = 300
        let r: Double = 0.07 / 12.0
        let steps = 120  // one point per quarter-month for smoothness

        for i in 0...steps {
            let months = Double(i) / Double(steps) * 360.0
            let fv = months < 0.001 ? 0.0 : pmt * (pow(1 + r, months) - 1) / r
            let x = CGFloat(i) / CGFloat(steps) * w
            let y = h - CGFloat(min(fv / maxVal, 1.0)) * h
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

private struct WaitFiveYrsGrowthPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let maxVal: Double = 400_000
        let pmt: Double = 300
        let r: Double = 0.07 / 12.0
        let delayMonths: Double = 60
        let steps = 120

        for i in 0...steps {
            let totalMonths = Double(i) / Double(steps) * 360.0
            let invested = max(0, totalMonths - delayMonths)
            let fv = invested < 0.001 ? 0.0 : pmt * (pow(1 + r, invested) - 1) / r
            let x = CGFloat(i) / CGFloat(steps) * w
            let y = h - CGFloat(min(fv / maxVal, 1.0)) * h
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

private struct StartNowAreaFill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = StartNowGrowthPath().path(in: rect)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Needs/Wants Category Bottom Sheet

private struct NeedsWantsCategorySheet: View {
    let category: String

    private var isNeeds: Bool { category == "needs" }
    private var accentColor: Color { isNeeds ? AppColors.accentPurple : AppColors.accentBlue }

    private let needsItems: [(icon: String, name: String)] = [
        ("cart.fill",         "Groceries"),
        ("house.fill",        "Rent / Mortgage"),
        ("car.fill",          "Transport"),
        ("cross.fill",        "Healthcare"),
        ("bolt.fill",         "Utilities"),
    ]
    private let wantsItems: [(icon: String, name: String)] = [
        ("fork.knife",              "Dining Out"),
        ("film",                    "Entertainment"),
        ("bag.fill",                "Shopping"),
        ("airplane",                "Travel"),
        ("apps.iphone",             "Subscriptions"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row
            HStack(spacing: 10) {
                Circle().fill(accentColor).frame(width: 10, height: 10)
                Text(isNeeds ? "Needs" : "Wants")
                    .font(.h3)
                    .foregroundColor(.white)
                Spacer()
                Text(isNeeds ? "$1,984" : "$1,216")
                    .font(.h3)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, 24)

            Text(isNeeds ? "Essentials you need to live" : "Nice-to-haves and lifestyle spending")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, 4)

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.top, 16)

            VStack(spacing: 0) {
                ForEach(isNeeds ? needsItems : wantsItems, id: \.name) { item in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: item.icon)
                                .font(.system(size: 15))
                                .foregroundColor(accentColor)
                        }
                        Text(item.name)
                            .font(.bodyRegular)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, AppSpacing.screenPadding)

                    Rectangle()
                        .fill(AppColors.surfaceBorder)
                        .frame(height: 0.5)
                        .padding(.leading, AppSpacing.screenPadding + 50)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .background(AppColors.backgroundSecondary.ignoresSafeArea())
    }
}
