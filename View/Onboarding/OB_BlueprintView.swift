//
//  OB_BlueprintView.swift
//  Flamora app
//
//  Onboarding Step 9 - Blueprint 结果总结
//

import SwiftUI

struct OB_BlueprintView: View {
    var data: OnboardingData
    var onNext: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)

            Text("\(data.userName), here is\nyour roadmap.")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)
                .animation(.easeOut(duration: 0.5), value: appear)

            Spacer().frame(height: AppSpacing.xl)

            // 曲线图区域
            ZStack {
                // 简化曲线
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h * 0.85))
                        path.addCurve(
                            to: CGPoint(x: w, y: h * 0.15),
                            control1: CGPoint(x: w * 0.35, y: h * 0.75),
                            control2: CGPoint(x: w * 0.65, y: h * 0.25)
                        )
                    }
                    .stroke(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )

                    // 起点标记
                    Circle()
                        .fill(AppColors.gradientStart)
                        .frame(width: 10, height: 10)
                        .position(x: 5, y: h * 0.85)

                    // 终点旗帜
                    Image(systemName: "flag.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: AppColors.gradientFire,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .position(x: w - 10, y: h * 0.1)
                }
                .frame(height: 160)
                .padding(.horizontal, 8)
            }
            .padding(20)
            .background(AppColors.backgroundCard.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1 : 0.95)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: appear)

            Spacer().frame(height: AppSpacing.lg)

            // 关键数据
            HStack(spacing: 16) {
                StatBox(
                    label: "Freedom Age",
                    value: "\(data.freedomAge)",
                    delay: 0.3
                )

                StatBox(
                    label: "Years Left",
                    value: "\(data.yearsToFire)",
                    delay: 0.4
                )

                StatBox(
                    label: "Target",
                    value: formatCurrency(data.fireNumber),
                    delay: 0.5
                )
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)

            Spacer().frame(height: AppSpacing.lg)

            // Speed Boost 提示
            HStack(spacing: 12) {
                Text("\u{1F525}")
                    .font(.h3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Speed Boost")
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    Text("To retire 2 years earlier, increase monthly savings by \(data.currencySymbol)200.")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(16)
            .background(AppColors.backgroundCard.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.brandPrimary.opacity(0.3), lineWidth: 1)
            )
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.6), value: appear)

            Spacer()

            // Save My Plan 按钮
            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text("Save My Plan")
                    Image(systemName: "lock.fill")
                        .font(.caption)
                }
                .font(.bodyRegular)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.7), value: appear)
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .onAppear { appear = true }
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "\(data.currencySymbol)\(String(format: "%.1fM", value / 1_000_000))"
        } else if value >= 1_000 {
            return "\(data.currencySymbol)\(String(format: "%.0fK", value / 1_000))"
        }
        return "\(data.currencySymbol)\(Int(value))"
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let label: String
    let value: String
    let delay: Double

    @State private var appear = false

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.h2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: AppColors.gradientFire,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.backgroundCard.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .scaleEffect(appear ? 1 : 0.8)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5).delay(delay)) {
                appear = true
            }
        }
    }
}
