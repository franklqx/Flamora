//
//  OB_AgeView.swift
//  Flamora app
//
//  Onboarding - 年龄 & 货币（Financial Snapshot 1/5）
//  玻璃风格年龄滑块保留并升级
//

import SwiftUI

struct OB_AgeView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void
    var onBack: () -> Void
    @State private var showCurrencyPicker = false
    @State private var hasInitialized = false
    private let ageRange: ClosedRange<Double> = 18...65

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    OB_SnapshotProgress(current: 1, total: 5)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, AppSpacing.md)

                    Spacer().frame(height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Great, \(data.userName.isEmpty ? "Friend" : data.userName)!")
                            .font(.obQuestion)
                            .foregroundColor(.white)
                        Text("Let's crunch your numbers")
                            .font(.obQuestion)
                            .foregroundColor(.white)
                    }

                    Spacer().frame(height: AppSpacing.xl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR AGE")
                            .font(.obStepLabel)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.8)

                        ageGlassCard
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRIMARY CURRENCY")
                            .font(.obStepLabel)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.8)

                        currencyButton
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // Sticky CTA
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                OB_PrimaryButton(title: "Next", action: onNext)
                .background(Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            _ = Self._sliderSetup
            guard !hasInitialized else { return }
            hasInitialized = true
            if let code = Locale.current.currency?.identifier,
               let match = currencyOptions.first(where: { $0.code == code }) {
                data.currencyCode = match.code
                data.currencySymbol = match.symbol
                data.country = match.country
            }
        }
        .sheet(isPresented: $showCurrencyPicker) {
            OB_CurrencyPickerSheet(data: data, isPresented: $showCurrencyPicker)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 年龄玻璃卡片

    private var ageGlassCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Spacer()
                Text("\(Int(data.age))")
                    .font(.system(size: 64, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentGradient)
                    .contentTransition(.numericText())
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(minWidth: 80, alignment: .center)
                Spacer()
            }
            .frame(height: 80)

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    // 渐变轨道在最底层
                    GeometryReader { geo in
                        let progress = CGFloat((data.age - ageRange.lowerBound) / (ageRange.upperBound - ageRange.lowerBound))
                        let thumbOffset: CGFloat = 14 // thumb 半径，避免渐变条超出
                        let trackWidth = geo.size.width - thumbOffset * 2

                        ZStack(alignment: .leading) {
                            // 底色轨道
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: trackWidth, height: 4)

                            // 渐变进度
                            Capsule()
                                .fill(accentGradient)
                                .frame(width: trackWidth * progress, height: 4)
                        }
                        .offset(x: thumbOffset)
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 28)
                    .allowsHitTesting(false)

                    // Slider 在上层，thumb 覆盖在进度条上面
                    Slider(value: $data.age, in: ageRange, step: 1)
                        .frame(height: 28)
                }
                .frame(height: 28)

                HStack {
                    Text("\(Int(ageRange.lowerBound))")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("\(Int(ageRange.upperBound))")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(height: 18)
            }
            .frame(height: 62)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(accentGradient)
                Text(ageMicrocopy)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(minHeight: 238)
        .background(AppColors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - 货币选择按钮

    private var currencyButton: some View {
        Button {
            showCurrencyPicker = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.country)
                        .font(.bodyRegular)
                        .foregroundColor(.white)
                    Text("\(data.currencyCode) \(data.currencySymbol)")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, 20)
            .frame(height: 64)
            .background(AppColors.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.borderDefault, lineWidth: 1)
            )
        }
    }

    // MARK: - Age Microcopy

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

    private var ageMicrocopy: String {
        let age = Int(data.age)
        if age < 30 {
            return "Time on your side. Small savings snowball fast."
        } else if age <= 45 {
            return "Earning power at its peak. Let's use it."
        } else {
            return "Start earlier than you think. Let's prove it."
        }
    }
}

// MARK: - Currency Picker Sheet

private struct OB_CurrencyPickerSheet: View {
    @Bindable var data: OnboardingData
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List(currencyOptions) { option in
                Button {
                    data.country = option.country
                    data.currencyCode = option.code
                    data.currencySymbol = option.symbol
                    isPresented = false
                } label: {
                    HStack {
                        Text(option.country)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(option.code) (\(option.symbol))")
                            .foregroundColor(.secondary)
                        if data.currencyCode == option.code {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.accentBlue)
                        }
                    }
                }
            }
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_AgeView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
