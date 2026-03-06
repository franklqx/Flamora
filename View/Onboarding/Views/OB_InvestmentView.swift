//
//  OB_InvestmentView.swift
//  Flamora app
//
//  Onboarding - Step 12: Investment Portfolio (Snapshot 4/5)
//

import SwiftUI

struct OB_InvestmentView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var investmentValue: Double = 0
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?
    private let investmentRange: ClosedRange<Double> = 0...2_000_000

    private var monthlyPassiveIncome: Int {
        Int((investmentValue * 0.04) / 12)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // 左半屏点击返回（与 AgeView 一致）
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: geo.size.width / 2)
                        .contentShape(Rectangle())
                        .onTapGesture { onBack() }
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    OB_SnapshotProgress(current: 4, total: 5)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, AppSpacing.md)

                    Spacer().frame(height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's your total investment portfolio value?")
                            .font(.obQuestion)
                            .foregroundColor(.white)
                        Text("Including stocks, bonds, retirement (401k, IRA), crypto, etc.")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer().frame(height: AppSpacing.xl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("INVESTMENT PORTFOLIO")
                            .font(.obStepLabel)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.8)

                        investmentCard
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    if showInsight {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PASSIVE INCOME")
                                .font(.obStepLabel)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(0.8)

                            passiveIncomeCard
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // Sticky CTA（与 AgeView 一致）
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                OB_PrimaryButton(title: "Next", action: {
                    data.currentNetWorth = "\(Int(investmentValue))"
                    onNext()
                })
                .background(Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            _ = Self._sliderSetup
            if let saved = Double(data.currentNetWorth), saved > 0 {
                investmentValue = saved
                showInsight = true
            }
        }
    }

    // MARK: - 投资玻璃卡片（与 AgeView 滑块样式一致）

    private var investmentCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Spacer()
                Text(data.currencySymbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Text(formattedInvestment)
                    .font(.system(size: 48, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentGradient)
                    .contentTransition(.numericText())
                Spacer()
            }
            .frame(height: 80)

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        let progress = CGFloat((investmentValue - investmentRange.lowerBound) / (investmentRange.upperBound - investmentRange.lowerBound))
                        let thumbOffset: CGFloat = 14
                        let trackWidth = geo.size.width - thumbOffset * 2

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: trackWidth, height: 4)
                            Capsule()
                                .fill(accentGradient)
                                .frame(width: trackWidth * progress, height: 4)
                        }
                        .offset(x: thumbOffset)
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 28)
                    .allowsHitTesting(false)

                    Slider(value: $investmentValue, in: investmentRange, step: 1000)
                        .frame(height: 28)
                        .onChange(of: investmentValue) { _, _ in
                            scheduleInsight()
                        }
                }
                .frame(height: 28)

                HStack {
                    Text("\(data.currencySymbol)0")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("\(data.currencySymbol)2M")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(height: 18)
            }
            .frame(height: 62)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(minHeight: 200)
        .background(AppColors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.accentBlue, AppColors.accentPurple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private static let _sliderSetup: Void = {
        UISlider.appearance().thumbTintColor = .white
        UISlider.appearance().minimumTrackTintColor = .clear
        UISlider.appearance().maximumTrackTintColor = .clear
    }()

    private var formattedInvestment: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: investmentValue)) ?? "\(Int(investmentValue))"
    }

    // MARK: - Passive Income Card

    private var passiveIncomeCard: some View {
        let passive = Double(monthlyPassiveIncome)

        return VStack(spacing: 16) {
            // 大数字：月被动收入
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Spacer()
                Text(data.currencySymbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(formatNumber(passive))
                    .font(.system(size: 48, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentGradient)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: monthlyPassiveIncome)
                Text("/mo")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
            }

            // 分割线
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // 计算说明
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Portfolio")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text(formatCurrency(investmentValue))
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                Text("×")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                VStack(spacing: 4) {
                    Text("4% Rule")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text("÷ 12")
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                Spacer()
                Text("=")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                VStack(spacing: 4) {
                    Text("Monthly")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text(formatCurrency(passive))
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentGradient)
                        .lineLimit(1)
                }
            }

            // 鼓励语
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(accentGradient)
                Text(passiveMicrocopy)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(AppColors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var passiveMicrocopy: String {
        switch monthlyPassiveIncome {
        case 5000...: return "You're already financially free. Let's confirm it."
        case 2000..<5000: return "Strong foundation — FIRE is within reach."
        case 500..<2000: return "Growing nicely. Consistency compounds fast."
        case 1..<500: return "Every dollar invested works for you 24/7."
        default: return "Everyone starts at zero. Let's build your plan."
        }
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(data.currencySymbol)\(formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }

    private func scheduleInsight() {
        insightWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) {
                showInsight = true
            }
        }
        insightWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_InvestmentView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
