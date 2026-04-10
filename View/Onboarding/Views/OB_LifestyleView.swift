//
//  OB_LifestyleView.swift
//  Flamora app
//
//  Onboarding - Step 13: Retirement Lifestyle (Snapshot 5/5)
//

import SwiftUI
import UIKit

struct OB_LifestyleView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var selectedType = "maintain"
    @State private var customAmountText = ""
    @FocusState private var isCustomInputFocused: Bool

    private var expenses: Double {
        Double(data.monthlyExpenses) ?? 0
    }

    private let options: [(key: String, title: String, subtitle: String, multiplier: Double)] = [
        ("minimalist", "Lean FIRE", "Minimalist & Free", 0.8),
        ("maintain", "Comfortable FIRE", "Current Lifestyle", 1.0),
        ("upgrade", "Fat FIRE", "Upgraded Living", 1.5),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: OB_OnboardingHeader.height)

                        Spacer().frame(height: AppSpacing.sm)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("What kind of retirement life do you want?")
                                .font(.obQuestion)
                                .foregroundStyle(AppColors.inkPrimary)
                            Text("Choose your target lifestyle in retirement")
                                .font(.bodySmall)
                                .foregroundColor(AppColors.inkSoft)
                        }

                        Spacer().frame(height: AppSpacing.xl)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("RETIREMENT LIFESTYLE")
                                .font(.cardRowMeta)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(0.8)

                            VStack(spacing: 12) {
                                ForEach(options, id: \.key) { option in
                                    lifestyleCard(option: option)
                                }
                            }
                        }

                        Spacer().frame(height: 16)

                        if selectedType != "custom" {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedType = "custom"
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.footnoteSemibold)
                                        .foregroundColor(AppColors.inkSoft)
                                    Text("Set my own target")
                                        .font(.bodySmall)
                                        .foregroundColor(AppColors.inkSoft)
                                }
                                .padding(.top, 4)
                            }
                            .buttonStyle(.plain)
                        }

                        if selectedType == "custom" {
                            HStack(spacing: 8) {
                                Text(data.currencySymbol)
                                    .font(.h4)
                                    .foregroundColor(AppColors.textTertiary)
                                TextField("Monthly amount", text: $customAmountText)
                                    .font(.h4)
                                    .foregroundStyle(AppColors.inkPrimary)
                                    .keyboardType(.numberPad)
                                    .focused($isCustomInputFocused)
                                Text("/mo")
                                    .font(.bodySmall)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(AppColors.glassCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .stroke(LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientMiddle, AppColors.gradientEnd], startPoint: .leading, endPoint: .trailing), lineWidth: 1.5)
                            )
                            .id("customInput")
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("customInput", anchor: .center)
                                    }
                                }
                            }
                        }

                        Spacer().frame(height: 32)
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            // 底部 CTA — 和 ScrollView 同级，键盘弹出时自动上移
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [AppColors.shellBg2.opacity(0), AppColors.shellBg2],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                OB_PrimaryButton(title: "Build My Roadmap", isValid: selectedType != "custom" || (Double(customAmountText) ?? 0) > 0, action: {
                    data.fireType = selectedType
                    if selectedType == "custom" {
                        data.targetMonthlySpend = Double(customAmountText) ?? expenses
                    } else if let option = options.first(where: { $0.key == selectedType }) {
                        data.targetMonthlySpend = expenses * option.multiplier
                    }
                    onNext()
                })
            }
            .padding(.bottom, 16)
            .background(AppColors.shellBg2)
            .ignoresSafeArea(edges: .bottom)
        }
        .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: { isCustomInputFocused = false }) {
                    Image(systemName: "checkmark")
                }
            }
        }
        .onAppear {
            if !data.fireType.isEmpty {
                selectedType = data.fireType
            }
        }
    }

    // MARK: - Lifestyle Card

    @ViewBuilder
    private func lifestyleCard(option: (key: String, title: String, subtitle: String, multiplier: Double)) -> some View {
        let isSelected = selectedType == option.key
        let amount = expenses * option.multiplier

        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3)) {
                selectedType = option.key
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)

                    HStack(spacing: 0) {
                        Text(option.subtitle)
                            .foregroundColor(AppColors.inkSoft)
                        Text(" · \(formatAmount(amount))/mo")
                            .foregroundColor(AppColors.inkSoft)
                    }
                    .font(.bodySmall)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle")
                        .font(.detailTitle)
                        .foregroundStyle(LinearGradient(
                            colors: [AppColors.gradientStart, AppColors.gradientMiddle, AppColors.gradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(isSelected ? LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientMiddle, AppColors.gradientEnd], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [AppColors.inkBorder], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(data.currencySymbol)\(formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        OB_LifestyleView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
