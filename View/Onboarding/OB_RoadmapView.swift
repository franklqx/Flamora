//
//  OB_RoadmapView.swift
//  Flamora app
//
//  Flamora Roadmap — 个性化结果长页面
//  位置: 加载页之后，Aha Moment 之前
//  目标: 交付结果 + 制造紧迫感 + 期待感 → 驱动 "Unlock My Full Plan"
//

import SwiftUI

struct OB_RoadmapView: View {
    var data: OnboardingData
    var onNext: () -> Void

    // 动画触发（仅触发一次）
    @State private var didAnimate = false

    // 从 OnboardingData 派生出完整指标和文案
    private var metrics: RoadmapMetrics {
        FreedomProjectionCalculator.compute(from: data)
    }
    private var copy: RoadmapCopy {
        RoadmapCopyResolver.resolve(metrics: metrics)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // 可滚动内容区域
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // 顶部导航标题
                    RoadmapNavBar()

                    // 区域 1: 顶部标题（希望 + 冲击）
                    RoadmapHeroSection(
                        copy: copy,
                        animated: didAnimate
                    )

                    // 区域 2: KPI 卡片（清晰感）
                    RoadmapKpiCardsSection(
                        copy: copy,
                        animated: didAnimate
                    )

                    // 区域 3: 里程碑时间线（定位感）
                    if copy.showTimeline {
                        RoadmapTimelineSection(
                            progress: metrics.timelineProgress,
                            animated: didAnimate
                        )
                    } else if let placeholder = copy.timelinePlaceholder {
                        RoadmapTimelinePlaceholderSection(text: placeholder)
                    }

                    // 区域 4: 紧迫感卡片（FOMO ⚡）
                    RoadmapUrgencySection(
                        copy: copy,
                        animated: didAnimate
                    )

                    // 区域 5: 锁定洞察（期待感 🔒）
                    RoadmapLockedInsightsSection(
                        copy: copy,
                        animated: didAnimate
                    )

                    // 底部留白（为 sticky CTA 腾空间）
                    Spacer().frame(height: 110)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, 20)
            }

            // 区域 6: Sticky CTA（固定底部）
            RoadmapStickyCTA(onNext: {
                OB_AnalyticsLogger.log(.roadmapCtaTapped, metrics: metrics)
                onNext()
            })
        }
        .onAppear {
            if !didAnimate {
                didAnimate = true
                OB_AnalyticsLogger.log(.roadmapViewed, metrics: metrics)
            }
        }
    }
}

// MARK: - Top Nav Bar

private struct RoadmapNavBar: View {
    var body: some View {
        HStack {
            Text("FLAMORA ROADMAP")
                .font(.label)
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.2)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview("Case E — Normal") {
    let data = OnboardingData()
    data.userName       = "Alex"
    data.age            = 30
    data.monthlyIncome  = "6000"
    data.monthlyExpenses = "3800"
    data.currentNetWorth = "25000"
    data.fireType       = "maintain"
    data.targetMonthlySpend = 3800
    data.currencySymbol = "$"
    return OB_RoadmapView(data: data, onNext: {})
}

#Preview("Case A — Can't Save") {
    let data = OnboardingData()
    data.userName       = "Sam"
    data.age            = 28
    data.monthlyIncome  = "3000"
    data.monthlyExpenses = "3200"
    data.currentNetWorth = "0"
    data.fireType       = "maintain"
    data.targetMonthlySpend = 3200
    data.currencySymbol = "$"
    return OB_RoadmapView(data: data, onNext: {})
}

#Preview("Case B — Very Close") {
    let data = OnboardingData()
    data.userName       = "Jordan"
    data.age            = 38
    data.monthlyIncome  = "12000"
    data.monthlyExpenses = "3000"
    data.currentNetWorth = "800000"
    data.fireType       = "maintain"
    data.targetMonthlySpend = 3000
    data.currencySymbol = "$"
    return OB_RoadmapView(data: data, onNext: {})
}

#Preview("Case D — Very Far") {
    let data = OnboardingData()
    data.userName       = "Chris"
    data.age            = 45
    data.monthlyIncome  = "2500"
    data.monthlyExpenses = "2300"
    data.currentNetWorth = "1000"
    data.fireType       = "maintain"
    data.targetMonthlySpend = 2300
    data.currencySymbol = "$"
    return OB_RoadmapView(data: data, onNext: {})
}
