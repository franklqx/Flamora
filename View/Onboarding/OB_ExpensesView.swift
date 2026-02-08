//
//  OB_ExpensesView.swift
//  Flamora app
//
//  Onboarding Step 6 - 月支出
//

import SwiftUI

struct OB_ExpensesView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 80)

                Text("And how much do\nyou spend monthly?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)

                Spacer().frame(height: 8)

                Text("Rent, food, bills, fun. A rough estimate is fine.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer().frame(height: AppSpacing.xl)

                HStack(spacing: 8) {
                    Text(data.currencySymbol)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)

                    TextField("0", text: $data.monthlyExpenses)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                }
                .padding(.horizontal, 20)
                .frame(height: 72)
                .background(AppColors.backgroundCard.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                if let _ = Double(data.monthlyExpenses), data.savingsRate > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                        Text("You're saving \(Int(data.savingsRate))% of your income.")
                            .font(.bodySmall)
                    }
                    .foregroundColor(AppColors.success)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.success.opacity(0.1))
                    .clipShape(Capsule())
                    .padding(.top, AppSpacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: data.monthlyExpenses)
                }

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
        (Double(data.monthlyExpenses) ?? 0) > 0
    }
}
