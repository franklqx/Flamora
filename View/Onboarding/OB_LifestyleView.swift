//
//  OB_LifestyleView.swift
//  Flamora app
//
//  Onboarding Step 8 - 退休生活方式（Financial Snapshot 5/5）
//

import SwiftUI

struct OB_LifestyleView: View {
    var data: OnboardingData
    var onNext: () -> Void

    @State private var selected: String = "maintain"
    @State private var showCustomInput = false
    @State private var customAmountText = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 40)

                    Text("What kind of retirement\nlife do you want?")
                        .font(.obQuestion)
                        .foregroundColor(.white)
                        .lineSpacing(2)

                    Spacer().frame(height: AppSpacing.xl)

                    // 三个选项
                    VStack(spacing: 12) {
                        LifestyleCard(
                            title: "Lean FIRE",
                            desc: "Minimalist & Free",
                            monthlyLabel: monthlyLabel(multiplier: 0.8),
                            key: "minimalist",
                            isSelected: selected == "minimalist",
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selected = "minimalist"
                                    showCustomInput = false
                                }
                            }
                        )

                        LifestyleCard(
                            title: "Comfortable FIRE",
                            desc: "Current Lifestyle",
                            monthlyLabel: monthlyLabel(multiplier: 1.0),
                            key: "maintain",
                            isSelected: selected == "maintain",
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selected = "maintain"
                                    showCustomInput = false
                                }
                            }
                        )

                        LifestyleCard(
                            title: "Fat FIRE",
                            desc: "Upgraded Living",
                            monthlyLabel: monthlyLabel(multiplier: 1.5),
                            key: "upgrade",
                            isSelected: selected == "upgrade",
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selected = "upgrade"
                                    showCustomInput = false
                                }
                            }
                        )

                        // 自定义目标
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selected = "custom"
                                showCustomInput = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                Text("Set my own target")
                                    .font(.bodySmall)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.top, 4)
                        }
                        .buttonStyle(.plain)

                        if showCustomInput {
                            HStack(spacing: 8) {
                                Text(data.currencySymbol)
                                    .font(.h4)
                                    .foregroundColor(AppColors.textTertiary)
                                TextField("Monthly amount", text: $customAmountText)
                                    .font(.h4)
                                    .foregroundColor(.white)
                                    .keyboardType(.numberPad)
                                Text("/mo")
                                    .font(.bodySmall)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .stroke(AppColors.borderDefault, lineWidth: 1)
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    Spacer().frame(height: 100)
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

                Button(action: {
                    applySelection()
                    onNext()
                }) {
                    Text("Build My Roadmap")
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
    }

    // MARK: - Helpers

    private func monthlyLabel(multiplier: Double) -> String {
        let base = Double(data.monthlyExpenses) ?? 0
        let val = base > 0 ? base * multiplier : 0
        if val <= 0 { return "" }
        if val >= 1000 {
            return "\(data.currencySymbol)\(String(format: "%.1f", val / 1000))K/mo"
        }
        return "\(data.currencySymbol)\(Int(val))/mo"
    }

    private func applySelection() {
        data.fireType = selected
        let expenses = Double(data.monthlyExpenses) ?? 0
        switch selected {
        case "minimalist": data.targetMonthlySpend = expenses * 0.8
        case "upgrade":    data.targetMonthlySpend = expenses * 1.5
        case "custom":
            if let customVal = Double(customAmountText), customVal > 0 {
                data.targetMonthlySpend = customVal
            } else {
                data.targetMonthlySpend = expenses
            }
        default:           data.targetMonthlySpend = expenses
        }
    }
}

// MARK: - Lifestyle Card

struct LifestyleCard: View {
    let title: String
    let desc: String
    let monthlyLabel: String
    let key: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { onTap() }
        }) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    if !monthlyLabel.isEmpty {
                        Text("\(desc) · \(monthlyLabel)")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                isSelected
                    ? AppColors.surface
                    : AppColors.surface.opacity(0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        isSelected ? Color.white.opacity(0.5) : AppColors.borderDefault,
                        lineWidth: isSelected ? 1.5 : 0.75
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        let data = OnboardingData()
        let _ = { data.monthlyExpenses = "4000"; data.currencySymbol = "$" }()
        OB_LifestyleView(data: data, onNext: {})
    }
}
