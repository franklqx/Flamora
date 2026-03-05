//
//  OB_AgeView.swift
//  Flamora app
//
//  Onboarding - Step 9: Age & Currency (Snapshot 1/5)
//

import SwiftUI

struct OB_AgeView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var ageText = ""
    @State private var showCurrencyPicker = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    OB_BackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                OB_SnapshotProgress(current: 1)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                Spacer().frame(height: 32)

                // Title
                Text("Great, \(data.userName)!\nLet's crunch your numbers.")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 40)

                // YOUR AGE
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR AGE")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(1)

                    TextField("", text: $ageText, prompt: Text("28")
                        .foregroundColor(AppColors.textTertiary))
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(AppColors.textPrimary)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(AppColors.backgroundCard)
                        .cornerRadius(AppRadius.md)
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 24)

                // PRIMARY CURRENCY
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRIMARY CURRENCY")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(1)

                    Button {
                        showCurrencyPicker = true
                    } label: {
                        HStack {
                            Text("\(data.currencySymbol)  \(data.currencyCode)")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding()
                        .background(AppColors.backgroundCard)
                        .cornerRadius(AppRadius.md)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer()

                // CTA
                OB_PrimaryButton(
                    title: "Next",
                    disabled: ageText.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    data.age = Double(ageText) ?? 28
                    onNext()
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        .onAppear {
            ageText = "\(Int(data.age))"
            // Auto-detect currency from device locale on first visit
            if data.age == 28 {
                if let code = Locale.current.currency?.identifier,
                   let match = currencyOptions.first(where: { $0.code == code }) {
                    data.currencyCode = match.code
                    data.currencySymbol = match.symbol
                    data.country = match.country
                }
            }
        }
        .sheet(isPresented: $showCurrencyPicker) {
            OB_CurrencyPickerSheet(
                selectedCode: data.currencyCode,
                onSelect: { option in
                    data.currencyCode = option.code
                    data.currencySymbol = option.symbol
                    data.country = option.country
                    showCurrencyPicker = false
                }
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Currency Picker Sheet

private struct OB_CurrencyPickerSheet: View {
    let selectedCode: String
    let onSelect: (CurrencyOption) -> Void

    var body: some View {
        NavigationStack {
            List(currencyOptions) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack {
                        Text(option.symbol)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 40, alignment: .leading)
                        Text(option.code)
                            .font(.system(size: 16, weight: .medium))
                        Text("— \(option.country)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        if option.code == selectedCode {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.brandPrimary)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    OB_AgeView(data: OnboardingData(), onNext: {}, onBack: {})
        .background(AppBackgroundView())
}
