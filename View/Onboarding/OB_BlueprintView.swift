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
    
    // API 集成状态变量
    @State private var fireSummary: FireSummaryDisplayData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("fireNumber") private var savedFireNumber: Double = 0
    @AppStorage("freedomAge") private var savedFreedomAge: Int = 0
    @AppStorage("yearsLeft") private var savedYearsLeft: Int = 0
    @AppStorage("savingsRate") private var savedSavingsRate: Double = 0
    
    private let apiService = APIService.shared

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

                    Circle()
                        .fill(AppColors.gradientStart)
                        .frame(width: 10, height: 10)
                        .position(x: 5, y: h * 0.85)

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

            // ========== 修改：显示真实 API 数据 ==========
            if isLoading {
                // Loading 状态
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color.white)
                    
                    Text("Calculating your path to freedom...")
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(height: 120)
                
            } else if let summary = fireSummary {
                // 成功 - 显示真实数据
                HStack(spacing: 16) {
                    StatBox(
                        label: "Freedom Age",
                        value: "\(summary.freedomAge)",
                        delay: 0.3
                    )
                    
                    StatBox(
                        label: "Years Left",
                        value: "\(summary.yearsLeft)",
                        delay: 0.4
                    )
                    
                    StatBox(
                        label: "Target",
                        value: formatCurrency(summary.fireNumber),
                        delay: 0.5
                    )
                }
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)
                
            } else if let error = errorMessage {
                // 错误状态
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    
                    Text("Oops!")
                        .font(.h3)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(error)
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button(action: {
                        Task {
                            await createProfile()
                        }
                    }) {
                        Text("Try Again")
                            .font(.bodyRegular)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textInverse)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 200)
            }
            // ==========================================

            Spacer().frame(height: AppSpacing.lg)

            // Savings Rate 提示（只在成功时显示）
            if let summary = fireSummary {
                HStack(spacing: 12) {
                    Text("🎯")
                        .font(.h3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Savings Rate")
                            .font(.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        Text("Keep saving \(summary.savingsRate, specifier: "%.1f")% of your income to reach FIRE.")
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
            }

            Spacer()

            // Save My Plan 按钮
            Button(action: {
                saveDataAndContinue()
            }) {
                HStack(spacing: 8) {
                    Text("Save My Plan")
                    Image(systemName: "arrow.right")
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
        .task {
            await createProfile()
        }
    }
    
    // MARK: - API Call
    private func createProfile() async {
        print("🔥 开始调用 API...")
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔥 发送请求到后端...")
            let response = try await apiService.createUserProfile(data: data)
            
            print("🔥 API 调用成功！")
            print("🔥 FIRE Number: \(response.data.fireSummary.fireNumber)")
            print("🔥 Freedom Age: \(response.data.fireSummary.freedomAge)")
            print("🔥 Years Left: \(response.data.fireSummary.yearsLeft)")
            
            fireSummary = FireSummaryDisplayData(from: response.data.fireSummary)
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appear = true
            }
            
        } catch let error as APIError {
            print("❌ API 错误: \(error)")
            errorMessage = error.localizedDescription
        } catch {
            print("❌ 未知错误: \(error)")
            errorMessage = "An unexpected error occurred. Please try again."
        }
        
        print("🔥 API 调用结束")
        isLoading = false
    }
    
    // MARK: - Save and Continue
    private func saveDataAndContinue() {
        guard let summary = fireSummary else { return }
        
        // 保存到 UserDefaults
        savedFireNumber = summary.fireNumber
        savedFreedomAge = summary.freedomAge
        savedYearsLeft = summary.yearsLeft
        savedSavingsRate = summary.savingsRate
        hasCompletedOnboarding = true
        
        // 继续到下一页
        onNext()
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
