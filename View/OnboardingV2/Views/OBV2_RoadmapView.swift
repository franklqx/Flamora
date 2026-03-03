//
//  OBV2_RoadmapView.swift
//  Flamora app
//
//  V2 Onboarding - Step 15: FIRE Roadmap (Core Conversion Page)
//

import SwiftUI

struct OBV2_RoadmapView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    // Animation states
    @State private var showTitle = false
    @State private var showCards = false
    @State private var timelineProgress: CGFloat = 0
    @State private var showOptimization = false
    @State private var showUrgency = false
    @State private var showInsight: [Bool] = [false, false, false]

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    OBV2_BackButton(action: onBack)
                    Spacer()
                }
                .overlay {
                    Text("Flamora Roadmap")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(1)
                }
                .padding(.horizontal, AppSpacing.md)

                // MARK: - Scrollable Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        dynamicTitleSection
                        dataCardsSection
                        milestoneTimelineSection
                        optimizationSection
                        urgencyCardSection
                        lockedInsightsSection
                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, 16)
                }
            }

            // MARK: - Sticky Bottom CTA
            stickyBottomCTA
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Section 1: Dynamic Title

    @ViewBuilder
    private var dynamicTitleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if data.savingsRate <= 0 {
                // cannotSave
                Text("Let's find your\nstarting point")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("Most people have hidden savings in their spending.")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textSecondary)
            } else if data.freedomAge <= Int(data.age) + 5 {
                // almostFree
                Text("You can reach freedom\nat age \(data.freedomAge)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("You're ahead of 95% of people your age.")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.success)
                Text("You're almost there.")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textSecondary)
            } else if (Double(data.currentNetWorth) ?? 0) == 0 && data.savingsRate > 0 {
                // notInvesting
                Text("You can reach freedom\nat age \(data.freedomAge)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(data.yearsToFire) years from now")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textSecondary)
            } else if data.freedomAge > 65 {
                // veryFar
                Text("Your journey starts\ntoday")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("Small changes compound into big results.")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                // normal
                Text("You can reach freedom\nat age \(data.freedomAge)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(data.yearsToFire) years from now")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .opacity(showTitle ? 1 : 0)
    }

    // MARK: - Section 2: Data Cards

    @ViewBuilder
    private var dataCardsSection: some View {
        HStack(spacing: 12) {
            dataCard(
                label: "SAVINGS RATE",
                value: "\(Int(data.savingsRate))%",
                footer: "Current"
            )
            dataCard(
                label: "TARGET",
                value: formatFireNumber(data.fireNumber),
                footer: "Freedom number"
            )
        }
        .opacity(showCards ? 1 : 0)
        .offset(y: showCards ? 0 : 20)
    }

    @ViewBuilder
    private func dataCard(label: String, value: String, footer: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
                .tracking(1)

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(footer)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppColors.backgroundCard)
        .cornerRadius(16)
    }

    // MARK: - Section 3: Milestone Timeline

    @ViewBuilder
    private var milestoneTimelineSection: some View {
        let progress = min(1, max(0, data.fireProgress / 100))

        VStack(spacing: 0) {
            // "You are here" label
            GeometryReader { geo in
                let xPos = max(40, min(geo.size.width - 40, geo.size.width * CGFloat(progress)))
                Text("You are here · \(Int(data.fireProgress))%")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize()
                    .position(x: xPos, y: 8)
            }
            .frame(height: 20)

            // Progress bar + dot
            GeometryReader { geo in
                let w = geo.size.width
                let dotX = max(6, min(w - 6, w * CGFloat(progress)))

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color(hex: "#333333"))
                        .frame(height: 4)

                    // Filled
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, w * CGFloat(progress) * timelineProgress), height: 4)

                    // Milestone dots
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { pos in
                        Circle()
                            .fill(pos <= progress ? AppColors.gradientEnd : Color(hex: "#555555"))
                            .frame(width: 6, height: 6)
                            .position(x: w * CGFloat(pos), y: 2)
                    }

                    // "You are here" dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .white.opacity(0.5), radius: 8)
                        .position(x: dotX, y: 2)
                }
            }
            .frame(height: 12)

            Spacer().frame(height: 10)

            // Milestone labels
            milestoneLabels
        }
    }

    @ViewBuilder
    private var milestoneLabels: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer()
            milestoneLabel("Investment\ncovers your\nrent")
            Spacer()
            Spacer()
            milestoneLabel("Half your life\nis funded")
            Spacer()
            Spacer()
            milestoneLabel("Freedom\nwithin reach")
            Spacer()
            Spacer()
            milestoneLabel("You're\nfree 🔥")
        }
    }

    @ViewBuilder
    private func milestoneLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(AppColors.textTertiary)
            .multilineTextAlignment(.center)
            .frame(width: 70)
    }

    // MARK: - Section: Optimization Suggestion

    @ViewBuilder
    private var optimizationSection: some View {
        let isAlmostFree = data.freedomAge <= Int(data.age) + 5 && data.savingsRate > 0
        let isCannotSave = data.savingsRate <= 0
        let isVeryFar = data.freedomAge > 65

        if !isAlmostFree {
            VStack(alignment: .leading, spacing: 8) {
                if isCannotSave {
                    Text("On average, users discover $200–400/month in potential savings within the first week.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                } else if isVeryFar {
                    let tenYearValue = data.suggestedExtraInvestment * 12 * ((pow(1.07, 10) - 1) / 0.07)
                    Text("By investing just \(formatAmount(data.suggestedExtraInvestment)) more per month, you could build \(formatAmount(tenYearValue)) in 10 years.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    // normal or notInvesting
                    Text("Invest just \(formatAmount(data.suggestedExtraInvestment)) more per month — free by \(data.optimizedFreedomAge)")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)

                    Text("That's \(data.yearsSaved) years earlier.")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.success)
                }
            }
            .opacity(showOptimization ? 1 : 0)
        }
    }

    // MARK: - Section 4: Urgency Card

    @ViewBuilder
    private var urgencyCardSection: some View {
        HStack(spacing: 0) {
            // Left orange accent
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.warning)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                if data.savingsRate <= 0 {
                    // cannotSave
                    Text("⚡ The cost of not knowing")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Without tracking, the average person overspends $300–500/month without realizing it.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(3)
                } else if data.freedomAge <= Int(data.age) + 5 {
                    // almostFree
                    Text("⚡ Don't lose momentum")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("You're this close. A small slip in spending could push your freedom date back by months.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(3)
                } else if data.freedomAge > 65 {
                    // veryFar
                    Text("⚡ Time is your biggest asset")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("The earlier you start, the more compound interest works for you. Even 1 year makes a difference.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(3)
                } else {
                    // normal or notInvesting
                    Text("⚡ Every month you wait costs you")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("If you delay your plan by just 1 year, your freedom age moves from \(data.freedomAge) to \(data.freedomAge + data.delayPenalty). That's \(data.delayPenalty) extra years of working.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(3)
                }
            }
            .padding(16)
        }
        .background(AppColors.backgroundCard)
        .cornerRadius(AppRadius.md)
        .opacity(showUrgency ? 1 : 0)
    }

    // MARK: - Section 5: Locked Insights

    @ViewBuilder
    private var lockedInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Personalized Insights")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
            }

            let titles = insightTitles
            ForEach(0..<3, id: \.self) { index in
                lockedCard(title: titles[index])
                    .opacity(showInsight[index] ? 1 : 0)
                    .offset(y: showInsight[index] ? 0 : 20)
            }
        }
    }

    private var insightTitles: [String] {
        if data.savingsRate <= 0 {
            // cannotSave
            return [
                "Find hidden savings in your spending",
                "Your personalized budget plan",
                "First steps to start investing",
            ]
        } else if data.freedomAge <= Int(data.age) + 5 {
            // almostFree
            return [
                "How to protect your progress",
                "Optimize your asset allocation",
                "Tax-efficient withdrawal strategies",
            ]
        } else {
            return [
                "3 ways to reach freedom faster",
                "Your monthly saving plan",
                "Spending areas to optimize",
            ]
        }
    }

    @ViewBuilder
    private func lockedCard(title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ZStack {
                // Fake blurred UI elements
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.borderDefault)
                        .frame(width: 180, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.borderDefault)
                        .frame(width: 130, height: 10)
                    HStack(spacing: 12) {
                        Circle().fill(AppColors.borderDefault).frame(width: 32, height: 32)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.borderDefault)
                            .frame(width: 100, height: 10)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 80)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blur(radius: 10)

                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.bottom, 12)
        }
        .background(AppColors.backgroundCard)
        .cornerRadius(AppRadius.md)
    }

    // MARK: - Sticky Bottom CTA

    @ViewBuilder
    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [AppColors.backgroundPrimary.opacity(0), AppColors.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)

            VStack(spacing: 8) {
                OBV2_PrimaryButton(title: "Unlock My Full Plan", action: onNext)

                Text("Your complete roadmap with real data insights")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.bottom, AppSpacing.lg)
            .background(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Helpers

    private func formatFireNumber(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "\(data.currencySymbol)\(String(format: "%.1f", value / 1_000_000))M"
        }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return "\(data.currencySymbol)\(f.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }

    private func formatAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return "\(data.currencySymbol)\(f.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }

    // MARK: - Animations

    private func startAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
            withAnimation(.easeOut(duration: 0.4)) { showTitle = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) { showCards = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 1.5)) { timelineProgress = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeOut(duration: 0.4)) { showOptimization = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.4)) { showUrgency = true }
        }
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7 + Double(i) * 0.2) {
                withAnimation(.easeOut(duration: 0.4)) { showInsight[i] = true }
            }
        }
    }
}
