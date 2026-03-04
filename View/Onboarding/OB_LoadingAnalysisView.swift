//
//  OB_LoadingAnalysisView.swift
//  Flamora app
//
//  加载分析态 — Lifestyle 完成后、Roadmap 展示前播放
//  同步调用后端 API 并将结果缓存到 OnboardingData.apiFireSummary
//

import SwiftUI

struct OB_LoadingAnalysisView: View {
    var data: OnboardingData
    var onNext: () -> Void

    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = 0
    @State private var progressValue: CGFloat = 0
    @State private var step1Done = false
    @State private var step2Done = false
    @State private var step3Done = false
    @State private var step4Done = false
    @State private var hasAdvanced = false

    private let apiService = APIService.shared

    private let steps = [
        "Analyzing your income structure...",
        "Calculating your savings potential...",
        "Mapping your path to freedom...",
        "Building your personalized roadmap...",
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Flamora 星形 Logo
                ZStack {
                    // 光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppColors.gradientStart.opacity(0.15), Color.clear],
                                center: .center, startRadius: 0, endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .opacity(logoOpacity)

                    Image(systemName: "sparkle")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundColor(.white)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .rotationEffect(.degrees(logoRotation))
                }

                Spacer().frame(height: 56)

                // 分析步骤清单
                VStack(alignment: .leading, spacing: 20) {
                    LoadingCheckItem(text: steps[0], isDone: step1Done)
                    LoadingCheckItem(text: steps[1], isDone: step2Done)
                    LoadingCheckItem(text: steps[2], isDone: step3Done)
                    LoadingCheckItem(text: steps[3], isDone: step4Done)
                }
                .padding(.horizontal, 40)

                Spacer()

                // 底部进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: AppColors.gradientFire,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progressValue, height: 3)
                            .animation(.linear(duration: 3.2), value: progressValue)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .onAppear { startAnimation() }
        .task { await callAPIInBackground() }
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            logoRotation = 20
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            progressValue = 1.0
        }

        let delays: [(Double, () -> Void)] = [
            (0.9,  { withAnimation(.easeOut(duration: 0.4)) { step1Done = true } }),
            (1.6,  { withAnimation(.easeOut(duration: 0.4)) { step2Done = true } }),
            (2.2,  { withAnimation(.easeOut(duration: 0.4)) { step3Done = true } }),
            (2.8,  { withAnimation(.easeOut(duration: 0.4)) { step4Done = true } }),
        ]
        for (delay, action) in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            advanceIfNeeded()
        }
    }

    // MARK: - API Call（逻辑保持不变）

    private func callAPIInBackground() async {
        do {
            let response = try await apiService.createUserProfile(data: data)
            let summary  = FireSummaryDisplayData(from: response.data.fireSummary)
            await MainActor.run {
                data.apiFireSummary = summary
            }
        } catch {
            // 静默失败：Roadmap 使用本地计算结果
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run { advanceIfNeeded() }
    }

    private func advanceIfNeeded() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        onNext()
    }
}

// MARK: - Loading Check Item

struct LoadingCheckItem: View {
    let text: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if isDone {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                }
            }
            .frame(width: 26, height: 26)

            Text(text)
                .font(.bodyRegular)
                .foregroundColor(isDone ? .white : Color.white.opacity(0.35))
                .animation(.easeInOut(duration: 0.4), value: isDone)
        }
    }
}

#Preview {
    OB_LoadingAnalysisView(data: OnboardingData(), onNext: {})
}
