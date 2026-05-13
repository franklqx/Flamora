//
//  OB_WelcomeView.swift
//  Meridian
//
//  Onboarding - Step 1: Welcome Carousel (4 pages)
//  • 翻页：点击左半屏 ← / 点击右半屏 → / 左右滑动 / 动画完成后自动播放
//

import SwiftUI

// MARK: - Main Welcome View

struct OB_WelcomeView: View {
    let onNext: () -> Void

    @State private var currentSlide = 0
    @State private var slideDirection: Int = 1
    @State private var autoAdvanceTask: DispatchWorkItem?

    private let slides: [WelcomeSlide] = [
        WelcomeSlide(
            title: "Retire\non your terms",
            subtitle: "Track your FIRE progress.",
            cardType: .fireProgress,
            autoAdvanceDelay: 3.5
        ),
        WelcomeSlide(
            title: "See\nyour spending",
            subtitle: "Know exactly where every dollar goes.",
            cardType: .budget,
            autoAdvanceDelay: 5.5
        ),
        WelcomeSlide(
            title: "Build\nbetter habits",
            subtitle: "Save consistently and grow your future.",
            cardType: .savings,
            autoAdvanceDelay: 4.5
        ),
        WelcomeSlide(
            title: "Grow\nyour net worth",
            subtitle: "Watch your money work for you.",
            cardType: .netWorth,
            autoAdvanceDelay: 4.5
        ),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Main content column ──────────────────────────────────
            VStack(spacing: 0) {

                // App Logo
                Image("FlameIcon")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 56, height: 56)
                    .padding(.top, AppSpacing.xxl - AppSpacing.xs)

                // Slide headline
                VStack(spacing: AppSpacing.sm) {
                    Text(slides[currentSlide].title)
                        .font(.obWelcomeTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(AppSpacing.xs)
                    Text(slides[currentSlide].subtitle)
                        .font(.fieldBodyMedium)
                        .fontWeight(.regular)
                        .foregroundColor(AppColors.overlayWhiteOnGlass)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.md + AppSpacing.xs + AppSpacing.xs)
                .animation(.easeInOut(duration: 0.25), value: currentSlide)

                Spacer().frame(height: AppSpacing.lg + AppSpacing.xs)

                // Slide card
                Group {
                    switch slides[currentSlide].cardType {
                    case .fireProgress: WelcomeFireProgressCard()
                    case .budget:       WelcomeBudgetCard(isActive: currentSlide == 1)
                    case .savings:     WelcomeSavingsCard(isActive: currentSlide == 2)
                    case .netWorth:    WelcomeNetWorthCard(isActive: currentSlide == 3)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal:   .move(edge: slideDirection > 0 ? .leading  : .trailing).combined(with: .opacity)
                ))
                .id(currentSlide)
                .padding(.horizontal, AppSpacing.cardPadding)

                Spacer(minLength: AppSpacing.md + AppSpacing.xs + AppSpacing.xs)

                // Page indicator dots
                HStack(spacing: AppSpacing.sm) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentSlide ? AppColors.textPrimary : AppColors.overlayWhiteEmphasisStroke)
                            .frame(
                                width: i == currentSlide ? AppSpacing.cardPadding : AppSpacing.sm - AppSpacing.xs / 2,
                                height: AppSpacing.sm - AppSpacing.xs / 2
                            )
                            .animation(.easeInOut(duration: 0.2), value: currentSlide)
                    }
                }
                .padding(.bottom, AppSpacing.cardPadding)

                Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.sm)
            }

            // ── Tap + swipe overlay (excludes CTA area) ─────────────
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { navigate(by: -1) }
                        .frame(width: geo.size.width / 2)

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { navigate(by: 1) }
                        .frame(width: geo.size.width / 2)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 25)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            navigate(by: value.translation.width < 0 ? 1 : -1)
                        }
                )
            }
            .padding(.bottom, AppSpacing.xxl + AppSpacing.xxl + AppSpacing.xl + AppSpacing.md + AppSpacing.md + AppSpacing.sm)

            // Get Started CTA
            OB_PrimaryButton(title: "Get Started", style: .ctaBlack, action: onNext)
        }
        .background(
            LinearGradient(
                gradient: AppColors.heroWelcomeGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            scheduleAutoAdvance()
        }
    }

    // MARK: - Navigation

    private func navigate(by delta: Int) {
        autoAdvanceTask?.cancel()
        slideDirection = delta >= 0 ? 1 : -1
        withAnimation(.easeInOut(duration: 0.3)) {
            currentSlide = (currentSlide + delta + slides.count) % slides.count
        }
        scheduleAutoAdvance()
    }

    private func scheduleAutoAdvance() {
        autoAdvanceTask?.cancel()
        let slideIndex = currentSlide
        let slideCount = slides.count
        let delay = slides[slideIndex].autoAdvanceDelay
        let task = DispatchWorkItem {
            slideDirection = 1
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSlide = (slideIndex + 1) % slideCount
            }
            scheduleAutoAdvance()
        }
        autoAdvanceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }
}

// MARK: - Slide Model

private struct WelcomeSlide {
    enum CardType { case fireProgress, budget, savings, netWorth }
    let title: String
    let subtitle: String
    let cardType: CardType
    let autoAdvanceDelay: Double
}

// MARK: - Glass Card Base (透明玻璃质感立体卡片)

private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md + AppSpacing.xs + AppSpacing.xs)
            .frame(minHeight: 260)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .fill(.ultraThinMaterial)
                    .opacity(0.4)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.xl)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppColors.overlayWhiteOnGlass,
                                        AppColors.overlayWhiteAt60,
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: AppColors.backgroundPrimary.opacity(0.15), radius: AppRadius.md, x: 0, y: AppSpacing.sm - AppSpacing.xs / 2)
    }
}

// MARK: - Card 1: FIRE Timeline (Vision — 你的自由生活)

private struct WelcomeFireProgressCard: View {
    @State private var trimEnd: CGFloat = 0

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("FIRE TIMELINE")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.overlayWhiteOnGlass)
                        .tracking(1.2)
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.overlayWhiteOnGlass)
                }

                Spacer().frame(height: AppSpacing.sm + AppSpacing.xs + AppSpacing.xs - AppSpacing.xs / 2)

                Text("Financial freedom is within reach")
                    .font(.fieldBodyMedium)
                    .fontWeight(.regular)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(3)

                Spacer().frame(height: AppSpacing.cardPadding)

                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(AppColors.glassPillStroke, lineWidth: 9)
                            .frame(width: 118, height: 118)
                        Circle()
                            .trim(from: 0, to: trimEnd)
                            .stroke(AppColors.textPrimary, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .frame(width: 118, height: 118)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: AppSpacing.xs / 2) {
                            Text("67%")
                                .font(.h2)
                                .foregroundStyle(AppColors.textPrimary)
                            Text("ACHIEVED")
                                .font(.miniLabel)
                                .scaleEffect(7 / 9)
                                .foregroundColor(AppColors.overlayWhiteOnPhoto)
                                .tracking(0.6)
                        }
                    }
                    Spacer()
                }

                Spacer().frame(height: AppSpacing.md)

                // Bottom stats
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs / 2) {
                        Text("RETIRE AGE")
                            .font(.miniLabel)
                            .foregroundColor(AppColors.overlayWhiteForegroundMuted)
                            .tracking(0.4)
                        Text("35")
                            .font(.cardFigureSecondary)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .background(AppColors.overlayWhiteHigh)
                        .frame(height: AppSpacing.lg + AppSpacing.xs)

                    VStack(alignment: .trailing, spacing: AppSpacing.xs / 2) {
                        Text("DAYS TO GO")
                            .font(.miniLabel)
                            .foregroundColor(AppColors.overlayWhiteForegroundMuted)
                            .tracking(0.4)
                        Text("2,847")
                            .font(.cardFigureSecondary)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) { trimEnd = 0.67 }
        }
    }
}

// MARK: - Card 2: Budget

private struct WelcomeBudgetCard: View {
    let isActive: Bool

    @State private var needsProgress: CGFloat = 0       // 0 → 0.62
    @State private var wantsProgress: CGFloat = 0       // 0 → 0.38
    @State private var needsDisplayAmount: Int = 0        // 0 → 2678 (Timer-driven)
    @State private var wantsDisplayAmount: Int = 0        // 0 → 955  (Timer-driven)
    @State private var showPercentages = false
    @State private var showSubcategories = false
    @State private var subcategoryVisible: [Bool] = Array(repeating: false, count: 6)
    @State private var budgetAnimationTimers: [Timer] = []

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private func formattedNumber(_ value: Int) -> String {
        Self.amountFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: AppSpacing.xs) {
                    Circle().fill(AppColors.success).frame(width: AppSpacing.sm - AppSpacing.xs / 2, height: AppSpacing.sm - AppSpacing.xs / 2)
                    Text("AUTO-CATEGORIZED · THIS MONTH")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.overlayWhiteOnPhoto)
                        .tracking(0.3)
                }
                .padding(.bottom, AppSpacing.sm + AppSpacing.xs + AppSpacing.xs)

                budgetSection(
                    name: "NEEDS",
                    amount: needsDisplayAmount,
                    pct: "62% OF INCOME",
                    progress: needsProgress,
                    items: [("Rent","$1,768","41%"), ("Groceries","$614","14%"), ("Utilities","$296","7%")],
                    subcategoryIndices: [0, 2, 4]
                )

                Divider()
                    .background(AppColors.glassPillStroke)
                    .padding(.vertical, AppSpacing.sm + AppSpacing.xs + AppSpacing.xs)

                budgetSection(
                    name: "WANTS",
                    amount: wantsDisplayAmount,
                    pct: "38% OF INCOME",
                    progress: wantsProgress,
                    items: [("Dining","$420","10%"), ("Shopping","$325","8%"), ("Travel","$210","5%")],
                    subcategoryIndices: [1, 3, 5]
                )
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                needsProgress = 0
                wantsProgress = 0
                needsDisplayAmount = 0
                wantsDisplayAmount = 0
                showPercentages = false
                showSubcategories = false
                subcategoryVisible = Array(repeating: false, count: 6)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    startAnimation()
                }
            }
        }
        .onDisappear {
            invalidateBudgetAnimationTimers()
        }
    }

    private func invalidateBudgetAnimationTimers() {
        budgetAnimationTimers.forEach { $0.invalidate() }
        budgetAnimationTimers.removeAll()
    }

    private func animateCounter(from: Int, to: Int, duration: Double, update: @escaping (Int) -> Void) {
        let startTime = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            // easeOut cubic curve
            let eased = 1 - pow(1 - progress, 3)
            let current = Int(Double(from) + Double(to - from) * eased)
            update(current)
            if progress >= 1.0 {
                timer.invalidate()
                update(to)
            }
        }
        budgetAnimationTimers.append(timer)
    }

    private func startAnimation() {
        invalidateBudgetAnimationTimers()
        // Step 1 — Progress bars + percentage labels (~2s)
        withAnimation(.timingCurve(0.25, 0, 0.1, 1, duration: 2.0)) {
            needsProgress = 0.62
            wantsProgress = 0.38
            showPercentages = true
        }

        // Step 1 — Amount counters (Timer-driven, 2s, easeOut)
        animateCounter(from: 0, to: 2678, duration: 2.0) { needsDisplayAmount = $0 }
        animateCounter(from: 0, to: 955, duration: 2.0) { wantsDisplayAmount = $0 }

        // Step 2 — Subcategory expand + staggered slide-in (1.8s after start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 1.0)) {
                showSubcategories = true
            }

            // Interleaved stagger: 180ms intervals
            let staggerDelays = [0.0, 0.180, 0.360, 0.540, 0.720, 0.900]
            for i in 0..<6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + staggerDelays[i]) {
                    withAnimation(.easeOut(duration: 0.6)) {
                        subcategoryVisible[i] = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func budgetSection(name: String, amount: Int, pct: String, progress: CGFloat,
                               items: [(String, String, String)], subcategoryIndices: [Int]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.label)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(0.5)
                Spacer()
                Text("$" + formattedNumber(amount))
                    .font(.h4)
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
            }
            GeometryReader { g in
                Capsule()
                    .fill(AppColors.textPrimary)
                    .frame(width: g.size.width * progress, height: AppSpacing.xs / 2)
            }
            .frame(height: AppSpacing.xs / 2)

            Text(pct)
                .font(.miniLabel)
                .foregroundColor(AppColors.overlayWhiteForegroundMuted)
                .opacity(showPercentages ? 1 : 0)
                .padding(.bottom, AppSpacing.xs)

            VStack(spacing: 0) {
                if showSubcategories {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        let globalIndex = subcategoryIndices[index]
                        HStack(spacing: AppSpacing.xs) {
                            Text(item.0)
                                .font(.cardRowMeta)
                                .foregroundColor(AppColors.overlayWhiteOnGlass)
                            Spacer()
                            Text(item.1)
                                .font(.inlineLabel)
                                .foregroundStyle(AppColors.textPrimary)
                            Text(item.2)
                                .font(.miniLabel)
                                .foregroundColor(AppColors.overlayWhiteForegroundMuted)
                                .padding(.horizontal, AppSpacing.xs + AppSpacing.xs + AppSpacing.xs + AppSpacing.xs + AppSpacing.xs - AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs / 2)
                                .background(AppColors.overlayWhiteMid)
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, AppSpacing.xs / 2 + AppSpacing.xs / 4)
                        .opacity(subcategoryVisible[globalIndex] ? 1 : 0)
                        .offset(x: subcategoryVisible[globalIndex] ? 0 : -AppSpacing.cardPadding)
                    }
                }
            }
            .clipped()
        }
    }
}

// MARK: - Card 3: Savings Overview

private struct WelcomeSavingsCard: View {
    let isActive: Bool

    private let months = ["J","F","M","A","M","J","J","A","S","O","N","D"]
    // Jan(below), Feb(target), Mar(above), Apr(below), May(target), Jun(above),
    // Jul(target), Aug(above), Sep(below), Oct-Dec(future)
    private let values: [CGFloat] = [0.62, 0.75, 0.88, 0.58, 0.75, 0.85, 0.75, 0.95, 0.65, 0, 0, 0]
    private let targetRatio: CGFloat = 0.75

    @State private var barHeights: [CGFloat] = Array(repeating: 0, count: 12)
    @State private var displayAmount: Int = 0
    @State private var savingsCounterTimer: Timer?

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal; return f
    }()
    private func formatted(_ v: Int) -> String {
        "$" + (Self.formatter.string(from: NSNumber(value: v)) ?? "\(v)")
    }

    private func animateCounter(to target: Int, duration: Double, update: @escaping (Int) -> Void) {
        savingsCounterTimer?.invalidate()
        let start = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { t in
            let p = min(Date().timeIntervalSince(start) / duration, 1.0)
            let eased = 1 - pow(1 - p, 3)
            update(Int(Double(target) * eased))
            if p >= 1.0 {
                t.invalidate()
                update(target)
            }
        }
        savingsCounterTimer = timer
    }

    private func startAnimation() {
        savingsCounterTimer?.invalidate()
        savingsCounterTimer = nil
        // Bars: sequential grow-in — each bar fully grows before the next starts
        let barDuration = 0.22
        for i in 0..<values.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * barDuration) {
                withAnimation(.easeOut(duration: barDuration)) {
                    barHeights[i] = values[i]
                }
            }
        }
        // Amount counter — matches total bar animation duration so both finish together
        let totalDuration = barDuration * Double(values.count)
        animateCounter(to: 20200, duration: totalDuration) { displayAmount = $0 }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs + AppSpacing.xs) {
                Text("SAVING OVERVIEW")
                    .font(.miniLabel)
                    .foregroundColor(AppColors.overlayWhiteOnPhoto)
                    .tracking(0.8)

                VStack(alignment: .leading, spacing: AppSpacing.xs / 2) {
                    Text(formatted(displayAmount))
                        .font(.detailTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                    Text("Total saved this year")
                        .font(.label)
                        .foregroundColor(AppColors.overlayWhiteOnGlass)
                }

                GeometryReader { geo in
                    let n = months.count
                    let gap: CGFloat = AppSpacing.xs
                    let labelH: CGFloat = AppSpacing.sm + AppSpacing.xs + AppSpacing.xs
                    let barAreaH = geo.size.height - labelH
                    let barW = (geo.size.width - gap * CGFloat(n - 1)) / CGFloat(n)
                    // Y offset from top where a "target-height" bar's top sits
                    let targetY = barAreaH * (1 - targetRatio)

                    ZStack(alignment: .topLeading) {
                        // Full-width dashed target line
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: targetY))
                            p.addLine(to: CGPoint(x: geo.size.width, y: targetY))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [
                            AppSpacing.xs,
                            AppSpacing.xs - AppSpacing.xs / 2 + AppSpacing.xs / 4
                        ]))
                        .foregroundColor(AppColors.overlayWhiteForegroundSoft)

                        // "TARGET" label above right end of line
                        Text("TARGET")
                            .font(.miniLabel)
                            .scaleEffect(6 / 9)
                            .foregroundColor(AppColors.overlayWhiteForegroundMuted)
                            .tracking(0.3)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(y: targetY - (AppSpacing.sm + AppSpacing.xs + AppSpacing.xs - AppSpacing.xs / 2))

                        // Bars
                        HStack(alignment: .bottom, spacing: gap) {
                            ForEach(Array(zip(months, values).enumerated()), id: \.offset) { idx, pair in
                                let val = pair.1
                                let animH = barHeights[idx]
                                let isFuture = val == 0
                                let isAboveTarget = val >= targetRatio

                                VStack(spacing: AppSpacing.xs) {
                                    if isFuture {
                                        // Future month: small stub
                                        RoundedRectangle(cornerRadius: AppSpacing.xs / 2)
                                            .fill(AppColors.overlayWhiteHigh)
                                            .frame(width: barW, height: AppSpacing.sm - AppSpacing.xs / 2)
                                    } else {
                                        // Active: white if at/above target, gray if below
                                        RoundedRectangle(cornerRadius: AppSpacing.xs)
                                            .fill(isAboveTarget ? AppColors.textPrimary : AppColors.overlayWhiteEmphasisStroke)
                                            .frame(width: barW, height: max(AppSpacing.sm - AppSpacing.xs / 2, barAreaH * animH))
                                    }
                                    Text(pair.0)
                                        .font(.miniLabel)
                                        .scaleEffect(6 / 9)
                                        .foregroundColor(AppColors.overlayWhiteAt40)
                                        .frame(width: barW)
                                }
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    }
                }
                .frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.sm)

                HStack {
                    statItem(label: "TARGET RATE",   value: "20%",     trailing: false)
                    Divider().background(AppColors.overlayWhiteHigh).frame(height: AppSpacing.lg + AppSpacing.xs)
                    statItem(label: "TARGET SAVING", value: "$2,000",  trailing: true)
                }
            }
        }
        .onAppear { startAnimation() }
        .onChange(of: isActive) { _, newValue in
            guard newValue else { return }
            barHeights = Array(repeating: 0, count: 12)
            displayAmount = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { startAnimation() }
        }
        .onDisappear {
            savingsCounterTimer?.invalidate()
            savingsCounterTimer = nil
        }
    }

    @ViewBuilder
    private func statItem(label: String, value: String, trailing: Bool) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: AppSpacing.xs / 2) {
            Text(label)
                .font(.miniLabel)
                .foregroundColor(AppColors.overlayWhiteForegroundMuted)
                .tracking(0.4)
            Text(value)
                .font(.cardFigureSecondary)
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
    }
}

// MARK: - Card 4: Net Worth

private struct NetWorthLineShape: Shape {
    // 左下 (0,0.78) → 右上 (1,0.25)，涨跌波动但总体向上，类似真实 K 线图
    private let rawPts: [(CGFloat, CGFloat)] = [
        (0.00,0.78),(0.08,0.68),(0.17,0.75),(0.25,0.65),(0.33,0.70),
        (0.42,0.58),(0.50,0.62),(0.58,0.48),(0.67,0.55),(0.75,0.42),
        (0.83,0.50),(0.92,0.35),(0.96,0.40),(1.00,0.25)
    ]
    func path(in rect: CGRect) -> Path {
        let pts = rawPts.map { CGPoint(x: $0.0 * rect.width, y: $0.1 * rect.height) }
        var p = Path()
        p.move(to: pts[0])
        for i in 0..<pts.count - 1 {
            let cp1 = CGPoint(x: (pts[i].x + pts[i+1].x) / 2, y: pts[i].y)
            let cp2 = CGPoint(x: (pts[i].x + pts[i+1].x) / 2, y: pts[i+1].y)
            p.addCurve(to: pts[i+1], control1: cp1, control2: cp2)
        }
        return p
    }
}

private struct WelcomeNetWorthCard: View {
    let isActive: Bool

    @State private var trimEnd: CGFloat = 0
    @State private var displayAmount: Int = 0
    @State private var showDot = false
    @State private var pulse = false
    @State private var netWorthCounterTimer: Timer?

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal; return f
    }()
    private func formatted(_ v: Int) -> String {
        "$" + (Self.formatter.string(from: NSNumber(value: v)) ?? "\(v)")
    }

    private func animateCounter(to target: Int, duration: Double, update: @escaping (Int) -> Void) {
        netWorthCounterTimer?.invalidate()
        let start = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { t in
            let p = min(Date().timeIntervalSince(start) / duration, 1.0)
            let eased = 1 - pow(1 - p, 3)
            update(Int(Double(target) * eased))
            if p >= 1.0 {
                t.invalidate()
                update(target)
            }
        }
        netWorthCounterTimer = timer
    }

    private func startAnimation() {
        netWorthCounterTimer?.invalidate()
        netWorthCounterTimer = nil
        // 折线从左到右描绘
        withAnimation(.easeInOut(duration: 1.4).delay(0.2)) { trimEnd = 1.0 }
        // 金额 counter
        animateCounter(to: 210150, duration: 1.4) { displayAmount = $0 }
        // 末端光点在折线画完后出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            showDot = true
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("TOTAL NET WORTH")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.overlayWhiteOnPhoto)
                        .tracking(0.8)
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        Text(formatted(displayAmount))
                            .font(.h2)
                            .foregroundStyle(AppColors.textPrimary)
                            .monospacedDigit()
                        Text("+13.8%")
                            .font(.footnoteSemibold)
                            .foregroundColor(AppColors.accentGreen)
                            .opacity(displayAmount > 0 ? 1 : 0)
                    }
                }

                GeometryReader { geo in
                    ZStack {
                        // 折线描绘动画
                        NetWorthLineShape()
                            .trim(from: 0, to: trimEnd)
                            .stroke(AppColors.textPrimary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        // 末端脉冲光点 (曲线终点 y=0.25)
                        if showDot {
                            let endX = geo.size.width
                            let endY = geo.size.height * 0.25
                            Circle()
                                .fill(pulse ? Color.clear : AppColors.overlayWhiteEmphasisStroke)
                                .frame(width: AppSpacing.md + AppSpacing.xs + AppSpacing.xs, height: AppSpacing.md + AppSpacing.xs + AppSpacing.xs)
                                .position(x: endX, y: endY)
                            Circle()
                                .fill(AppColors.textPrimary)
                                .frame(width: AppSpacing.sm - AppSpacing.xs / 2, height: AppSpacing.sm - AppSpacing.xs / 2)
                                .position(x: endX, y: endY)
                        }
                    }
                }
                .frame(height: AppSpacing.xxl + AppSpacing.md + AppSpacing.xs + AppSpacing.xs)

                HStack(spacing: 0) {
                    ForEach(["1W","1M","3M","YTD","ALL"], id: \.self) { period in
                        let selected = period == "1M"
                        Text(period)
                            .font(.barMonthTick(selected: selected))
                            .foregroundColor(selected ? AppColors.textInverse : AppColors.overlayWhiteOnGlass)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(selected ? AppColors.textPrimary : Color.clear)
                            .clipShape(Capsule())
                    }
                }
                .padding(AppSpacing.xs)
                .background(AppColors.overlayWhiteMid)
                .clipShape(Capsule())
            }
        }
        .onAppear { startAnimation() }
        .onChange(of: isActive) { _, newValue in
            guard newValue else { return }
            trimEnd = 0; displayAmount = 0; showDot = false; pulse = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { startAnimation() }
        }
        .onDisappear {
            netWorthCounterTimer?.invalidate()
            netWorthCounterTimer = nil
        }
    }
}

#Preview {
    OB_WelcomeView(onNext: {})
        .background(AppBackgroundView())
}
