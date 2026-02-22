//
//  OB_IncomeView.swift
//  Flamora app
//
//  Onboarding Step 5 - 月收入
//

import SwiftUI

struct OB_IncomeView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 80)

                Text("What's your\nmonthly income?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)

                Spacer().frame(height: 8)

                Text("After taxes. This is the fuel for your freedom engine.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer().frame(height: AppSpacing.xl)

                HStack(spacing: 8) {
                    Text(data.currencySymbol)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)

                    TextField("0", text: $data.monthlyIncome)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                }
                .padding(.horizontal, 20)
                .frame(height: 72)
                .background(AppColors.backgroundCard.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                Spacer()
            }

            Button(action: {
                isFocused = false
                onNext()
            }) {
                Text("Next")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(isValid ? AppColors.textInverse : AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValid ? Color.white : AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(!isValid)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = false }
        .onAppear { isFocused = false }
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    private var isValid: Bool {
        (Double(data.monthlyIncome) ?? 0) > 0
    }
}

#Preview {
    OB_IncomeView(data: OnboardingData(), onNext: {})
        .background(AppBackgroundView())
}
