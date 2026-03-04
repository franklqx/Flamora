//
//  OB_AgeLocationView.swift
//  Flamora app
//
//  Onboarding Step 4 - 年龄 & 货币（Financial Snapshot 1/5）
//  玻璃风格年龄滑块保留并升级
//

import SwiftUI

struct OB_AgeLocationView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void
    @State private var showCurrencyPicker = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Great, \(data.userName.isEmpty ? "friend" : data.userName)! Let's crunch\nyour numbers.")
                            .font(.obQuestion)
                            .foregroundColor(.white)
                            .lineSpacing(2)
                    }

                    Spacer().frame(height: AppSpacing.xl)

                    // ── 年龄玻璃卡片（保留原有交互，升级视觉）────────────────
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR AGE")
                            .font(.obStepLabel)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.8)

                        ageGlassCard
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    // ── 货币选择 ─────────────────────────────────────────────
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

                Button(action: onNext) {
                    Text("Next")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerSheet(data: data, isPresented: $showCurrencyPicker)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 年龄玻璃卡片（核心控件，保留交互升级样式）

    private var ageGlassCard: some View {
        VStack(spacing: 16) {
            // 年龄大数字展示
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Spacer()
                Text("\(Int(data.age))")
                    .font(.system(size: 64, weight: .bold, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: Int(data.age))
                Spacer()
            }

            // 年龄滑块（最小触控区已满足 44pt 系统标准）
            VStack(spacing: 8) {
                Slider(value: $data.age, in: 18...65, step: 1)
                    .tint(AppColors.gradientStart)

                HStack {
                    Text("18")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("65")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            // 动态文案（保留原有逻辑）
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundColor(AppColors.gradientStart)
                Text(ageMicrocopy)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut, value: Int(data.age))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        // 玻璃材质背景（升级）
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

    // MARK: - Age Microcopy（保留原有逻辑）

    private var ageMicrocopy: String {
        let age = Int(data.age)
        if age < 30 {
            return "You have time on your side. Even small savings snowball fast."
        } else if age <= 45 {
            return "Your earning power is at its peak. Let's use it."
        } else {
            return "Every year you start earlier than you think. Let's prove it."
        }
    }
}

// MARK: - Currency Picker Sheet（保留原有逻辑）

struct CurrencyPickerSheet: View {
    var data: OnboardingData
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
                                .foregroundColor(.blue)
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
        OB_AgeLocationView(data: OnboardingData(), onNext: {})
    }
}
