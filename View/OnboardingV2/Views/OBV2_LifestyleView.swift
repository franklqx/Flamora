//
//  OBV2_LifestyleView.swift
//  Flamora app
//
//  V2 Onboarding - Step 13: Retirement Lifestyle (Snapshot 5/5)
//

import SwiftUI

struct OBV2_LifestyleView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var selectedType = "maintain"
    @State private var showCustomInput = false
    @State private var customAmountText = ""

    private var expenses: Double {
        Double(data.monthlyExpenses) ?? 0
    }

    private let options: [(key: String, title: String, subtitle: String, multiplier: Double)] = [
        ("minimalist", "Lean FIRE", "Minimalist & Free", 0.8),
        ("maintain", "Comfortable FIRE", "Current Lifestyle", 1.0),
        ("upgrade", "Fat FIRE", "Upgraded Living", 1.5),
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    OBV2_BackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                OBV2_SnapshotProgress(current: 5)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                Spacer().frame(height: 32)

                Text("What kind of\nretirement life do\nyou want?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 28)

                // Lifestyle cards
                VStack(spacing: 12) {
                    ForEach(options, id: \.key) { option in
                        lifestyleCard(option: option)
                    }

                    // Custom card (shown if selected)
                    if selectedType == "custom" {
                        customCard
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 16)

                // Custom target link
                if selectedType != "custom" {
                    Button {
                        showCustomInput = true
                    } label: {
                        Text("+ Set my own target")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }

                Spacer()

                // CTA
                OBV2_PrimaryButton(title: "Build My Roadmap") {
                    data.fireType = selectedType
                    if selectedType == "custom" {
                        data.targetMonthlySpend = Double(customAmountText) ?? expenses
                    } else if let option = options.first(where: { $0.key == selectedType }) {
                        data.targetMonthlySpend = expenses * option.multiplier
                    }
                    onNext()
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .onAppear {
            if !data.fireType.isEmpty {
                selectedType = data.fireType
            }
        }
        .alert("Set Custom Monthly Target", isPresented: $showCustomInput) {
            TextField("Amount", text: $customAmountText)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                if let amount = Double(customAmountText), amount > 0 {
                    selectedType = "custom"
                }
            }
        } message: {
            Text("Enter your desired monthly spending in retirement (\(data.currencySymbol))")
        }
    }

    // MARK: - Lifestyle Card

    @ViewBuilder
    private func lifestyleCard(option: (key: String, title: String, subtitle: String, multiplier: Double)) -> some View {
        let isSelected = selectedType == option.key
        let amount = expenses * option.multiplier

        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedType = option.key
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: 0) {
                        Text(option.subtitle)
                            .foregroundColor(AppColors.textSecondary)
                        Text(" · \(formatAmount(amount))/mo")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .font(.bodySmall)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.backgroundCard)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Card

    @ViewBuilder
    private var customCard: some View {
        let amount = Double(customAmountText) ?? 0

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text("\(formatAmount(amount))/mo")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundCard)
        .cornerRadius(AppRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.white, lineWidth: 1.5)
        )
    }

    // MARK: - Helpers

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(data.currencySymbol)\(formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }
}
