//
//  OB_AgeLocationView.swift
//  Flamora app
//
//  Onboarding Step 4 - 年龄 & 地区
//

import SwiftUI

struct OB_AgeLocationView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void
    @State private var showCurrencyPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 60)

            Text("Let's set your\ntimeline and currency.")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)

            Spacer().frame(height: AppSpacing.xl)

            // MARK: - Age Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Age")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                // 年龄数字
                Text("\(Int(data.age))")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .center)

                // 滑块
                Slider(value: $data.age, in: 18...65, step: 1)
                    .tint(AppColors.gradientStart)

                // 动态文案
                Text(ageMicrocopy)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .animation(.easeInOut, value: Int(data.age))
            }
            .padding(20)
            .background(AppColors.backgroundCard.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

            Spacer().frame(height: AppSpacing.lg)

            // MARK: - Currency Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Currency")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                Button {
                    showCurrencyPicker = true
                } label: {
                    HStack {
                        Text("\(data.country)")
                            .font(.bodyRegular)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text("\(data.currencyCode) (\(data.currencySymbol))")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textSecondary)

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(AppColors.backgroundCard.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                }
            }

            Spacer()

            // Next 按钮
            Button(action: onNext) {
                Text("Next")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerSheet(data: data, isPresented: $showCurrencyPicker)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var ageMicrocopy: String {
        let age = Int(data.age)
        if age < 30 {
            return "Time is your superpower! Compound interest loves you."
        } else if age <= 45 {
            return "The prime building years. Let's maximize them."
        } else {
            return "It's never too late. The best time to start is now."
        }
    }
}

// MARK: - Currency Picker Sheet
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
    OB_AgeLocationView(data: OnboardingData(), onNext: {})
        .background(AppBackgroundView())
}
