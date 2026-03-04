//
//  RoadmapSectionComponents.swift
//  Flamora app
//
//  OB_RoadmapView 的六大区域子组件
//

import SwiftUI

// MARK: - 区域 1: Hero Section

struct RoadmapHeroSection: View {
    let copy: RoadmapCopy
    let animated: Bool

    @State private var opacity: Double = 0
    @State private var blur: CGFloat = 8
    @State private var counterValue: Int = 0
    @State private var targetCounter: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Line 1 — 白色主标题
            Text(copy.heroLine1)
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Line 2 — 品牌高亮色
            Text(copy.heroLine2)
                .font(.h4)
                .foregroundColor(AppColors.brandSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Line 3 — 渐变大字（冲击数字）
            Text(copy.heroLine3)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: AppColors.gradientFire,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(opacity)
        .blur(radius: blur)
        .onAppear {
            guard animated else {
                opacity = 1; blur = 0
                return
            }
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1
                blur    = 0
            }
        }
    }
}

// MARK: - 区域 2: KPI Cards Section

struct RoadmapKpiCardsSection: View {
    let copy: RoadmapCopy
    let animated: Bool

    @State private var offset: CGFloat = 24
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            RoadmapKpiCard(
                label:    copy.leftCardLabel,
                value:    copy.leftCardValue,
                sublabel: copy.leftCardSublabel
            )
            RoadmapKpiCard(
                label:    copy.rightCardLabel,
                value:    copy.rightCardValue,
                sublabel: copy.rightCardSublabel
            )
        }
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            guard animated else { offset = 0; opacity = 1; return }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                offset  = 0
                opacity = 1
            }
        }
    }
}

struct RoadmapKpiCard: View {
    let label: String
    let value: String
    let sublabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.label)
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.8)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(sublabel)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - 区域 3: Timeline Section

struct RoadmapTimelineSection: View {
    let progress: Double  // 0.0 – 1.0
    let animated: Bool

    @State private var drawProgress: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    private let milestones: [(fraction: Double, label: String)] = [
        (0.25, "Investments\ncover your rent"),
        (0.50, "Half your life\nis funded"),
        (0.75, "Freedom\nwithin reach"),
        (1.00, "You're free 🔥"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geo in
                let w = geo.size.width
                let trackY: CGFloat = 20

                ZStack(alignment: .topLeading) {
                    // 背景轨道
                    Capsule()
                        .fill(AppColors.surfaceInput)
                        .frame(width: w, height: 3)
                        .offset(y: trackY - 1.5)

                    // 进度填充（渐变）
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.gradientStart, AppColors.gradientMiddle, AppColors.gradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * drawProgress, height: 3)
                        .offset(y: trackY - 1.5)

                    // 里程碑节点
                    ForEach(milestones, id: \.fraction) { milestone in
                        let x = w * milestone.fraction
                        let reached = drawProgress >= milestone.fraction

                        Circle()
                            .fill(reached ? AppColors.gradientEnd : AppColors.surfaceInput)
                            .frame(width: 8, height: 8)
                            .offset(x: x - 4, y: trackY - 4)
                    }

                    // "You are here" 发光点
                    let dotX = w * min(drawProgress, 0.98)
                    ZStack {
                        // 脉冲环
                        Circle()
                            .strokeBorder(AppColors.gradientEnd.opacity(pulseOpacity), lineWidth: 2)
                            .frame(width: 18 * pulseScale, height: 18 * pulseScale)
                        // 实心点
                        Circle()
                            .fill(AppColors.gradientEnd)
                            .frame(width: 10, height: 10)
                    }
                    .offset(x: dotX - 9, y: trackY - 9)

                    // 里程碑标签（轨道下方）
                    ForEach(milestones, id: \.fraction) { milestone in
                        let x = w * milestone.fraction
                        Text(milestone.label)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(width: 70)
                            .offset(x: x - 35, y: trackY + 10)
                    }

                    // "You are here" 标签（轨道上方）
                    let labelX = min(max(w * drawProgress - 35, 0), w - 70)
                    VStack(spacing: 2) {
                        Text("\(Int(drawProgress * 100))%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.gradientEnd)
                        Text("You are here")
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .offset(x: labelX, y: -20)
                }
            }
            .frame(height: 80)
        }
        .padding(20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 1)
        )
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
                    drawProgress = progress
                }
            } else {
                drawProgress = progress
            }
            // 脉冲循环
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale   = 1.6
                pulseOpacity = 0.0
            }
        }
    }
}

// 情况 A 时的时间线替代文案卡片
struct RoadmapTimelinePlaceholderSection: View {
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "map")
                .font(.system(size: 20))
                .foregroundColor(AppColors.accentPurple)
            Text(text)
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - 区域 4: Urgency Section

struct RoadmapUrgencySection: View {
    let copy: RoadmapCopy
    let animated: Bool

    @State private var opacity: Double = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 橙色左边框
            Rectangle()
                .fill(AppColors.warning)
                .frame(width: 4)
                .clipShape(
                    RoundedRectangle(cornerRadius: 2)
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("⚡")
                        .font(.h4)
                    Text(copy.urgencyTitle)
                        .font(.h4)
                        .foregroundColor(AppColors.textPrimary)
                }

                Text(copy.urgencyBody)
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.warning.opacity(0.3 + glowOpacity * 0.15), lineWidth: 1)
        )
        .opacity(opacity)
        .onAppear {
            guard animated else { opacity = 1; return }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                opacity = 1
            }
            // 微弱橙色闪烁
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(1.2)) {
                glowOpacity = 1
            }
        }
    }
}

// MARK: - 区域 5: Locked Insights Section

struct RoadmapLockedInsightsSection: View {
    let copy: RoadmapCopy
    let animated: Bool

    @State private var card1Offset: CGFloat = 30
    @State private var card2Offset: CGFloat = 30
    @State private var card3Offset: CGFloat = 30
    @State private var cardsOpacity: [Double] = [0, 0, 0]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Personalized Insights")
                    .font(.h4)
                    .foregroundColor(AppColors.textPrimary)
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
            }

            LockedInsightCard(title: copy.insightCard1Title)
                .offset(y: card1Offset)
                .opacity(cardsOpacity[0])

            LockedInsightCard(title: copy.insightCard2Title)
                .offset(y: card2Offset)
                .opacity(cardsOpacity[1])

            LockedInsightCard(title: copy.insightCard3Title)
                .offset(y: card3Offset)
                .opacity(cardsOpacity[2])
        }
        .onAppear {
            guard animated else {
                card1Offset = 0; card2Offset = 0; card3Offset = 0
                cardsOpacity = [1, 1, 1]
                return
            }
            let animDelay = 0.8
            let stagger   = 0.2
            let configs: [(Double, Binding<CGFloat>, Int)] = [
                (animDelay,               $card1Offset, 0),
                (animDelay + stagger,     $card2Offset, 1),
                (animDelay + stagger * 2, $card3Offset, 2),
            ]
            for (delay, offsetBinding, idx) in configs {
                withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                    offsetBinding.wrappedValue = 0
                    cardsOpacity[idx] = 1
                }
            }
        }
    }
}

struct LockedInsightCard: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.bodyRegular)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // 模糊内容区域（占卡片 65%）
            ZStack {
                // 隐约可见的占位 UI（图表轮廓）
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        ForEach(0..<6, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 24, height: CGFloat(20 + i * 6))
                        }
                    }
                    HStack {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                    }
                }
                .padding(12)
                .blur(radius: 6)

                // 锁图标
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary)
                    Text("Unlock to reveal")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(AppColors.surfaceElevated)
            .clipShape(
                RoundedRectangle(cornerRadius: AppRadius.md)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - 区域 6: Sticky CTA

struct RoadmapStickyCTA: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onNext) {
                Text("Unlock My Full Plan")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }

            Text("Your complete roadmap with real data insights")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
