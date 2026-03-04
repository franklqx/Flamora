//
//  OB_AhaMomentView.swift
//  Flamora app
//
//  Aha Moment — 解锁前的最后一道价值主张
//  位置: Roadmap CTA 之后，Paywall 之前
//

import SwiftUI

struct OB_AhaMomentView: View {
    var onNext: () -> Void

    @State private var headerVisible = false
    @State private var stepsVisible: [Bool] = [false, false, false, false]
    @State private var footerVisible = false

    private let journeySteps: [(icon: String, label: String, isHighlighted: Bool)] = [
        ("scope",               "Set your goal",                 true),
        ("link",                "Connect accounts",              false),
        ("squares.grid.2x2",    "Get your personalized plan",    false),
        ("location.north",      "Auto-track progress",           false),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 52)

                // 标题
                Text("We'll guide you\nevery step of the way")
                    .font(.obQuestion)
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 16)

                Spacer().frame(height: 40)

                // 4 步旅程
                VStack(spacing: 0) {
                    ForEach(Array(journeySteps.enumerated()), id: \.offset) { index, step in
                        AhaJourneyStepRow(
                            icon:          step.icon,
                            label:         step.label,
                            isHighlighted: step.isHighlighted,
                            showConnector: index < journeySteps.count - 1
                        )
                        .opacity(stepsVisible[index] ? 1 : 0)
                        .offset(y: stepsVisible[index] ? 0 : 14)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                Spacer().frame(height: 32)

                Text("No spreadsheets. No guesswork. Just a system that keeps you on track — automatically.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .opacity(footerVisible ? 1 : 0)

                Spacer()

                // CTA
                Button(action: {
                    OB_AnalyticsLogger.log(.ahaViewed)
                    onNext()
                }) {
                    Text("Continue")
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
                .opacity(footerVisible ? 1 : 0)
            }
        }
        .onAppear {
            startAnimations()
            OB_AnalyticsLogger.log(.ahaViewed)
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.5)) {
            headerVisible = true
        }
        for i in 0..<journeySteps.count {
            withAnimation(.easeOut(duration: 0.4).delay(0.3 + Double(i) * 0.12)) {
                stepsVisible[i] = true
            }
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
            footerVisible = true
        }
    }
}

// MARK: - Journey Step Row

private struct AhaJourneyStepRow: View {
    let icon: String
    let label: String
    let isHighlighted: Bool
    let showConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 0) {
                ZStack {
                    if isHighlighted {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: AppColors.gradientFire,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                    } else {
                        Circle()
                            .fill(AppColors.surfaceElevated)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.borderDefault, lineWidth: 1)
                            )
                    }
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isHighlighted ? .black : AppColors.textTertiary)
                }

                if showConnector {
                    Rectangle()
                        .fill(AppColors.borderDefault)
                        .frame(width: 1, height: 32)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.h4)
                    .foregroundColor(isHighlighted ? .white : AppColors.textSecondary)
                    .padding(.top, 14)
            }

            Spacer()
        }
    }
}

#Preview {
    OB_AhaMomentView(onNext: {})
}
