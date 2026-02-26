//
//  OB_NetWorthView.swift
//  Flamora app
//
//  Onboarding Step 7 - 净资产
//

import SwiftUI

struct OB_NetWorthView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 80)

                Text("Do you have any\nsavings or investments?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)

                Spacer().frame(height: 8)

                Text("Any 401k, IRA, savings, or investments count. This is your head start.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer().frame(height: AppSpacing.xl)

                // 金额输入
                HStack(spacing: 8) {
                    Text(data.currencySymbol)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)

                    TextField("0", text: $data.currentNetWorth)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                }
                .padding(.horizontal, 20)
                .frame(height: 72)
                .background(AppColors.backgroundCard.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                Spacer().frame(height: 12)

                Text("Guessing is totally fine — you can update this anytime.")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)

                // Skip link
                Button {
                    data.currentNetWorth = "0"
                    isFocused = false
                    onNext()
                } label: {
                    Text("I'll Add This Later")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.info)
                }
                .padding(.top, 8)

                Spacer()
            }

            Button(action: {
                if data.currentNetWorth.isEmpty {
                    data.currentNetWorth = "0"
                }
                isFocused = false
                onNext()
            }) {
                Text("This Is My Head Start →")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = false }
        .onAppear { isFocused = false }
        .ignoresSafeArea(.keyboard, edges: .all)
    }
}

#Preview {
    OB_NetWorthView(data: OnboardingData(), onNext: {})
        .background(AppBackgroundView())
}
