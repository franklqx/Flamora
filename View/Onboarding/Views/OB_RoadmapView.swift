//
//  OB_RoadmapView.swift
//  Flamora app
//
//  Onboarding - Step 15: Before/After Roadmap (merged)
//  V3 — matches HTML prototype (roadmap-v3-prototype.html)
//

import SwiftUI
import UIKit

struct OB_RoadmapView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBackToLifestyle: () -> Void
    @Binding var backAction: (() -> Void)?

    // Core state
    @State private var isRevealed = false

    // Before reveal animations
    @State private var showTitle = false
    @State private var showCurrentBars = false
    @State private var showDataCards = false
    @State private var showCTA = false

    // After reveal animations
    @State private var showRevealedTitle = false
    @State private var hideDataCards = false
    @State private var showAfterDataCards = false
    @State private var showRevealedCTA = false

    // After card stagger + counting
    @State private var afterCard1Visible = false
    @State private var afterCard2Visible = false
    @State private var afterCard3Visible = false
    @State private var afterCard4Visible = false
    @State private var counterProgress: Double = 0
    @State private var showYearsSavedBadge = false
    @State private var countingAnimationTimer: Timer?

    // Info sheet
    @State private var showInfoSheet = false

    // Scroll
    @State private var scrollProxy: ScrollViewProxy?

    // Gradients
    private let brandGradient = LinearGradient(
        colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Bar count for timing calc (based on optimized range — chart shrinks to this on reveal)
    private var revealBarCount: Int {
        let totalYears = max(1, data.optimizedFreedomAge - Int(data.age))
        if totalYears > 30 {
            return (0..<totalYears).filter { $0 % 2 == 0 }.count
        }
        return totalYears
    }

    private var totalStagger: Double {
        Double(revealBarCount) * 0.045
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                gradient: AppColors.heroBrandLinearGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Anchor for scroll-to-top
                        Color.clear.frame(height: 0).id("top")

                        Spacer().frame(height: 56)

                        // 1. Back button + PREDICT + Title
                        headerSection
                            .padding(.horizontal, 26)
                            .padding(.bottom, 20)

                        // 3. Legend row
                        legendSection
                            .padding(.horizontal, 26)
                            .padding(.bottom, 12)

                        // 4. Chart (full bleed with 12pt padding)
                        chartSection

                        // 5. Bottom section
                        bottomSection
                            .padding(.horizontal, 26)
                            .padding(.top, 4)

                        Spacer().frame(height: 140)
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                    startBeforeAnimations()
                    updateBackAction()
                }
                .onChange(of: isRevealed) { _, _ in updateBackAction() }
            }

            // Sticky CTA
            stickyBottomCTA
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showInfoSheet) { infoSheet }
        .onDisappear {
            countingAnimationTimer?.invalidate()
            countingAnimationTimer = nil
        }
    }

    // MARK: - 1. Header (back button + PREDICT + title)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // PREDICT eyebrow
            Text("PREDICT")
                .font(.label)
                .foregroundColor(AppColors.overlayWhiteOnPhoto)
                .tracking(4)

            // Title (crossfade)
            ZStack(alignment: .leading) {
                beforeTitle
                    .opacity(isRevealed ? 0 : (showTitle ? 1 : 0))
                    .animation(.easeOut(duration: 0.5), value: isRevealed)

                afterTitle
                    .opacity(showRevealedTitle ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: showRevealedTitle)
            }
        }
    }

    private var beforeTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                switch data.userSituation {
                case .cannotSave:
                    HStack(spacing: 0) {
                        Text("At your current pace, financial freedom is ")
                            .foregroundStyle(AppColors.textPrimary)
                        Text("out of reach")
                            .foregroundStyle(brandGradient)
                        Text(".")
                            .foregroundStyle(AppColors.textPrimary)
                    }
                default:
                    if data.isFreedomAgeCapped {
                        HStack(spacing: 0) {
                            Text("You will reach financial independence at age ")
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(data.displayFreedomAge)+")
                                .foregroundStyle(brandGradient)
                            Text(".")
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    } else {
                        HStack(spacing: 0) {
                            Text("You will reach financial independence at age ")
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(data.freedomAge)")
                                .foregroundStyle(brandGradient)
                            Text(".")
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
            }
            .font(.detailTitle)
            .lineSpacing(3)

            Group {
                switch data.userSituation {
                case .cannotSave:
                    Text("You're spending everything you earn.")
                case .notInvesting:
                    Text("Your savings projected with 9% average annual returns.")
                default:
                    Text("Based on your current savings — no optimization.")
                }
            }
            .font(.footnoteRegular)
            .foregroundColor(AppColors.overlayWhiteForegroundMuted)
        }
    }

    private var afterTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                switch data.userSituation {
                case .cannotSave:
                    HStack(spacing: 0) {
                        Text("Start investing ")
                            .foregroundStyle(AppColors.textPrimary)
                        Text("\(formatCurrency(data.suggestedExtraInvestment))/mo")
                            .foregroundStyle(brandGradient)
                        Text(", you could be free by ")
                            .foregroundStyle(AppColors.textPrimary)
                        Text("\(data.optimizedFreedomAge)")
                            .foregroundStyle(brandGradient)
                        Text(".")
                            .foregroundStyle(AppColors.textPrimary)
                    }
                default:
                    if data.yearsSaved == 0 {
                        HStack(spacing: 0) {
                            Text("With Flamora, you'll build ")
                                .foregroundStyle(AppColors.textPrimary)
                            Text("+\(formatCompact(data.extraPortfolioValue)) more")
                                .foregroundStyle(brandGradient)
                            Text(" by age ")
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(data.optimizedFreedomAge)")
                                .foregroundStyle(brandGradient)
                            Text(".")
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    } else {
                        let yearText = data.yearsSaved == 1 ? "1 year sooner" : "\(data.yearsSaved) years sooner"
                        HStack(spacing: 0) {
                            Text("With Flamora, you'll be free by ")
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(data.optimizedFreedomAge)")
                                .foregroundStyle(brandGradient)
                            Text(" — that's ")
                                .foregroundStyle(AppColors.textPrimary)
                            Text(yearText)
                                .foregroundStyle(brandGradient)
                            Text(".")
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
            }
            .font(.detailTitle)
            .lineSpacing(3)

            Group {
                switch data.userSituation {
                case .cannotSave:
                    Text("Your current path has no timeline to freedom.")
                default:
                    if data.yearsSaved == 0 {
                        Text("You're already close — Flamora helps you finish strong.")
                    } else {
                        let label = data.isFreedomAgeCapped ? "\(data.displayFreedomAge)+" : "\(data.freedomAge)"
                        Text("Your current path has you working until \(label).")
                    }
                }
            }
            .font(.footnoteRegular)
            .foregroundColor(AppColors.overlayWhiteForegroundMuted)
        }
    }

    // MARK: - 3. Legend

    private var legendSection: some View {
        HStack(spacing: 8) {
            Spacer()

            // Flamora legend (after reveal)
            if isRevealed {
                HStack(spacing: 5) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.gradientEnd, AppColors.gradientMiddle],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 7, height: 7)
                    Text("Flamora")
                        .font(.label)
                        .foregroundColor(AppColors.overlayWhiteAt40)
                }
                .transition(.opacity)
            }

            // Current legend (always)
            HStack(spacing: 5) {
                Circle()
                    .fill(AppColors.overlayWhiteForegroundSoft)
                    .frame(width: 7, height: 7)
                Text("Current")
                    .font(.label)
                    .foregroundColor(AppColors.overlayWhiteAt40)
            }

            // Info button (after reveal)
            if isRevealed {
                Button(action: { showInfoSheet = true }) {
                    ZStack {
                        Circle()
                            .fill(AppColors.cardTopHighlight)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.overlayWhiteMid, lineWidth: 1)
                            )
                        Text("i")
                            .font(.label)
                            .foregroundColor(AppColors.overlayWhiteAt40)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: isRevealed)
    }

    // MARK: - 4. Chart

    private var chartSection: some View {
        let currentEnd = data.userSituation == .cannotSave
            ? min(Int(data.age) + 30, data.displayFreedomAge)
            : data.displayFreedomAge

        return ZStack {
            OB_BarChartView(
                startAge: Int(data.age),
                currentEndAge: currentEnd,
                optimizedEndAge: data.optimizedFreedomAge,
                startingNetWorth: Double(data.currentNetWorth) ?? 0,
                monthlySavings: data.monthlySavings,
                optimizedMonthlySavings: data.optimizedMonthlySavings,
                currencySymbol: data.currencySymbol,
                showCurrentBars: showCurrentBars,
                showOptimizedBars: isRevealed
            )
            .frame(height: 236) // 200 chart + 36 x-axis

            // cannotSave Before: overlay text
            if data.userSituation == .cannotSave && !isRevealed {
                Text("No investment growth")
                    .font(.bodySmallSemibold)
                    .foregroundColor(AppColors.overlayWhiteAt25)
                    .tracking(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(showCurrentBars ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: showCurrentBars)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - 5. Bottom section

    private var bottomSection: some View {
        VStack(spacing: 12) {
            // Before: 2x2 data cards (collapse when hidden)
            if !hideDataCards {
                beforeDataCards
                    .opacity(showDataCards ? 1 : 0)
                    .offset(y: showDataCards ? 0 : 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // After: 2x2 data cards
            if showAfterDataCards {
                afterDataCards
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(.easeOut(duration: 0.5), value: hideDataCards)
        .animation(.easeOut(duration: 0.5), value: showAfterDataCards)
    }

    // MARK: - Before Data Cards (2x2)

    private var beforeDataCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if data.userSituation == .cannotSave {
                dataCard(label: "MONTHLY INCOME", value: formatCurrency(Double(data.monthlyIncome) ?? 0))
                dataCard(label: "MONTHLY EXPENSES", value: formatCurrency(Double(data.monthlyExpenses) ?? 0))
                dataCard(label: "SAVINGS RATE", value: "0%")
                dataCard(label: "NET WORTH", value: formatCurrency(Double(data.currentNetWorth) ?? 0))
            } else {
                dataCard(label: "MONTHLY INCOME", value: formatCurrency(Double(data.monthlyIncome) ?? 0))
                dataCard(label: "CURRENT INVESTMENT", value: formatCurrency(Double(data.currentNetWorth) ?? 0))
                dataCard(label: "SAVINGS RATE", value: "\(Int(data.savingsRate))%")
                dataCard(label: "LIFESTYLE SPENDING", value: formatCurrency(lifestyleSpending))
            }
        }
    }

    @ViewBuilder
    private func dataCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.miniLabel)
                .foregroundColor(AppColors.overlayWhiteForegroundSoft)
                .tracking(1)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 22, alignment: .bottom)
            Text(value)
                .font(.detailTitle)
                .foregroundStyle(AppColors.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardTopHighlight, lineWidth: 1)
        )
    }

    // MARK: - After Data Cards (2x2) with stagger + counting

    private var afterDataCards: some View {
        let rateIncrease = data.optimizedSavingsRate - data.savingsRate
        let isCannotSave = data.userSituation == .cannotSave

        let extraDisplay = data.extraPortfolioValue * counterProgress
        let rateDisplay = data.optimizedSavingsRate * counterProgress
        let fireDisplay = data.fireNumber * counterProgress

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // Card 1: cannotSave → MONTHLY INVESTMENT, otherwise → EXTRA PORTFOLIO VALUE
            if isCannotSave {
                afterCard(label: "MONTHLY INVESTMENT") {
                    Text("\(formatCurrency(data.suggestedExtraInvestment))/mo")
                        .font(.detailTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.gradientEnd, AppColors.gradientMiddle],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .opacity(afterCard1Visible ? 1 : 0)
                .offset(y: afterCard1Visible ? 0 : 10)
                .animation(.easeOut(duration: 0.5), value: afterCard1Visible)
            } else {
                afterCard(label: "EXTRA PORTFOLIO VALUE") {
                    Text("+\(formatCompact(extraDisplay))")
                        .font(.detailTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.gradientEnd, AppColors.gradientMiddle],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .opacity(afterCard1Visible ? 1 : 0)
                .offset(y: afterCard1Visible ? 0 : 10)
                .animation(.easeOut(duration: 0.5), value: afterCard1Visible)
            }

            // Card 2: FREEDOM AGE — optimized age + delayed ↓ badge
            afterCard(label: "FREEDOM AGE") {
                HStack(spacing: 0) {
                    Text("\(data.optimizedFreedomAge)")
                        .font(.detailTitle)
                        .foregroundColor(AppColors.gradientEnd)

                    if showYearsSavedBadge && data.daysSaved > 0 {
                        Text(" \u{2193}\(data.daysSaved) days")
                            .font(.footnoteSemibold)
                            .foregroundStyle(AppColors.textPrimary)
                            .transition(.opacity)
                            .padding(.leading, 8)
                    }
                }
                .animation(.easeOut(duration: 0.4), value: showYearsSavedBadge)
            }
            .opacity(afterCard2Visible ? 1 : 0)
            .offset(y: afterCard2Visible ? 0 : 10)
            .animation(.easeOut(duration: 0.5), value: afterCard2Visible)

            // Card 3: SAVINGS RATE — optimized rate + ↑ delta
            afterCard(label: "SAVINGS RATE") {
                HStack(spacing: 0) {
                    Text("\(Int(rateDisplay))%")
                        .font(.detailTitle)
                        .foregroundColor(AppColors.gradientEnd)
                    if isCannotSave {
                        Text(" \u{2191}\(Int(data.optimizedSavingsRate))%")
                            .font(.footnoteSemibold)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.leading, 8)
                    } else if rateIncrease > 0 {
                        Text(" \u{2191}\(Int(rateIncrease))%")
                            .font(.footnoteSemibold)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.leading, 8)
                    }
                }
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            }
            .opacity(afterCard3Visible ? 1 : 0)
            .offset(y: afterCard3Visible ? 0 : 10)
            .animation(.easeOut(duration: 0.5), value: afterCard3Visible)

            // Card 4: FREEDOM # — pink, counting
            afterCard(label: "FREEDOM #") {
                Text(formatCompact(fireDisplay))
                    .font(.detailTitle)
                    .foregroundColor(AppColors.gradientMiddle)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .opacity(afterCard4Visible ? 1 : 0)
            .offset(y: afterCard4Visible ? 0 : 10)
            .animation(.easeOut(duration: 0.5), value: afterCard4Visible)
        }
    }

    @ViewBuilder
    private func afterCard(label: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.miniLabel)
                .foregroundColor(AppColors.overlayWhiteForegroundSoft)
                .tracking(1)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 22, alignment: .bottom)
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardTopHighlight, lineWidth: 1)
        )
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppColors.overlayBlackSoft.opacity(0), AppColors.overlayBlackSoft],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            VStack(spacing: 8) {
                ZStack {
                    // Before CTA (white)
                    OB_PrimaryButton(
                        title: "See My Flamora Plan",
                        style: .ctaWhite,
                        includeContainerPadding: false,
                        action: {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            triggerReveal()
                        }
                    )
                    .opacity(showRevealedCTA ? 0 : (showCTA ? 1 : 0))

                    // After CTA (gradient)
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onNext()
                    } label: {
                        Text("Get My Real Numbers \u{2192}")
                            .font(.figureSecondarySemibold)
                            .foregroundStyle(AppColors.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppColors.ctaWhite)
                            .overlay(
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(AppColors.glassCardBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .shadow(color: AppColors.overlayBlackSoft, radius: 16, y: 8)
                    }
                    .opacity(showRevealedCTA ? 1 : 0)
                }

                Text(showRevealedCTA ? "Connect accounts for live tracking" : "Unlock your optimized roadmap")
                    .font(.cardRowMeta)
                    .foregroundColor(AppColors.overlayWhiteForegroundSoft)
                    .animation(.easeOut(duration: 0.5), value: showRevealedCTA)
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.overlayBlackSoft)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Info Sheet

    private var infoSheet: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("How this is calculated")
                .font(.h4)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.bottom, AppSpacing.xs)

            infoRow(label: "Annual return", value: "9%")
            infoRow(label: "Monthly savings", value: formatCurrency(data.monthlySavings))
            infoRow(label: "Flamora optimized", value: formatCurrency(data.optimizedMonthlySavings))
            infoRow(label: "Your FIRE number", value: formatCompact(data.fireNumber))

            Divider().background(AppColors.cardTopHighlight)

            Text("Based on the historical nominal return of the S&P 500 (~10% annually since 1957), adjusted for estimated fees. Projections assume consistent contributions. Actual results vary with market conditions. Past performance does not guarantee future results.")
                .font(.cardRowMeta)
                .foregroundColor(AppColors.overlayWhiteForegroundSoft)
                .lineSpacing(3)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium])
        .presentationBackground(AppColors.surface)
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.bodySmall)
                .foregroundColor(AppColors.overlayWhiteOnPhoto)
            Spacer()
            Text(value)
                .font(.inlineFigureBold)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Helpers

    private var lifestyleSpending: Double {
        if data.targetMonthlySpend > 0 { return data.targetMonthlySpend }
        let expenses = Double(data.monthlyExpenses) ?? 0
        let multiplier: Double
        switch data.fireType {
        case "minimalist": multiplier = 0.8
        case "upgrade": multiplier = 1.5
        default: multiplier = 1.0
        }
        return expenses * multiplier
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return "\(data.currencySymbol)\(f.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "\(data.currencySymbol)\(String(format: "%.1f", value / 1_000_000))M"
        } else if value >= 1_000 {
            return "\(data.currencySymbol)\(Int(value / 1_000))K"
        }
        return formatCurrency(value)
    }

    // MARK: - Animations

    private func updateBackAction() {
        backAction = isRevealed ? reverseReveal : onBackToLifestyle
    }

    private func startBeforeAnimations() {
        withAnimation(.easeOut(duration: 0.6)) { showTitle = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showCurrentBars = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.4)) { showDataCards = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.3)) { showCTA = true }
        }
    }

    private func triggerReveal() {
        isRevealed = true

        // Scroll to top
        withAnimation(.easeOut(duration: 0.4)) {
            scrollProxy?.scrollTo("top", anchor: .top)
        }

        // TOTAL = revealBarCount * 45ms (gradient bar stagger duration)
        let total = totalStagger
        let afterCardsStart = total + 0.3

        // TOTAL + 150ms — title crossfade
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.15) {
            withAnimation(.easeOut(duration: 0.5)) { showRevealedTitle = true }
        }

        // TOTAL + 300ms — hide before cards, show after cards container
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCardsStart) {
            withAnimation(.easeOut(duration: 0.5)) {
                hideDataCards = true
                showAfterDataCards = true
            }

            // Start counting animation
            startCountingAnimation()
        }

        // Stagger individual card fade-ins (200ms interval)
        let cardStates = [
            { withAnimation(.easeOut(duration: 0.5)) { afterCard1Visible = true } },
            { withAnimation(.easeOut(duration: 0.5)) { afterCard2Visible = true } },
            { withAnimation(.easeOut(duration: 0.5)) { afterCard3Visible = true } },
            { withAnimation(.easeOut(duration: 0.5)) { afterCard4Visible = true } }
        ]
        for (i, setVisible) in cardStates.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + afterCardsStart + Double(i) * 0.2) {
                setVisible()
            }
        }

        // Show years saved badge: after card 2 appears + 0.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCardsStart + 0.2 + 0.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showYearsSavedBadge = true
            }
        }

        // CTA transition: after last card appears + 200ms
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCardsStart + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) { showRevealedCTA = true }
        }
    }

    private func reverseReveal() {
        // Step 1: Trigger gradient bar reverse stagger (right-to-left)
        // Setting isRevealed = false triggers bar chart's reverseOptimizedBars()
        withAnimation(.easeOut(duration: 0.3)) {
            isRevealed = false
        }

        // Step 2: Fade out After UI elements
        withAnimation(.easeOut(duration: 0.3)) {
            showRevealedCTA = false
            afterCard1Visible = false
            afterCard2Visible = false
            afterCard3Visible = false
            afterCard4Visible = false
            showYearsSavedBadge = false
        }
        counterProgress = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                showAfterDataCards = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showRevealedTitle = false
            }
        }

        // Step 3: After bar stagger + dual layout collapse + range expand, restore Before UI
        // Bar chart: stagger (count*0.045) + last bar anim (0.3) + dual collapse (0.3) + range expand
        let barReverseDuration = totalStagger + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + barReverseDuration) {
            withAnimation(.easeOut(duration: 0.3)) {
                hideDataCards = false
            }
        }
    }

    private func startCountingAnimation(duration: Double = 1.5) {
        countingAnimationTimer?.invalidate()
        let startTime = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let t = min(1.0, elapsed / duration)
            // easeOut cubic
            counterProgress = 1.0 - pow(1.0 - t, 3)
            if t >= 1.0 {
                timer.invalidate()
                counterProgress = 1.0
                countingAnimationTimer = nil
            }
        }
        countingAnimationTimer = timer
    }
}

#Preview {
    ZStack {
        LinearGradient(
            gradient: AppColors.heroBrandLinearGradient,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        OB_RoadmapView(data: OnboardingData(), onNext: {}, onBackToLifestyle: {}, backAction: .constant(nil))
    }
}
