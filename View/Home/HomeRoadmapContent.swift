//
//  HomeRoadmapContent.swift
//  Flamora app
//
//  Home Tab sheet primary content — “What happens next” roadmap (HTML: .roadmap).
//

import SwiftUI

struct HomeRoadmapContent: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                roadmapCard
                    .padding(.horizontal, AppSpacing.screenPadding)
            }
            .padding(.top, AppSpacing.cardGap)
            // 不在 ScrollView 主轴上使用 Spacer：会导致内容高度/裁切异常，出现「提前被一条线裁掉」。
            .padding(.bottom, AppSpacing.xl + AppSpacing.lg)
        }
        .scrollContentBackground(.hidden)
    }

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What happens next")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)
                .textCase(.uppercase)
                .padding(.bottom, AppSpacing.sm)

            Text("Three steps to unlock Home.")
                .font(.h3)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(-0.5)
                .padding(.bottom, AppSpacing.md)

            VStack(spacing: 0) {
                roadmapStep(
                    index: 1,
                    isCurrent: true,
                    title: "Set your FIRE goal",
                    detail: "Tell Flamora what future you're aiming for."
                )
                roadmapStep(
                    index: 2,
                    isCurrent: false,
                    title: "Connect your accounts",
                    detail: "Bring in your real numbers when you're ready."
                )
                roadmapStep(
                    index: 3,
                    isCurrent: false,
                    title: "Choose your path",
                    detail: "Apply the version of FIRE that fits your life.",
                    isLast: true
                )
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .fill(AppColors.glassCardBg)
                .shadow(color: AppColors.glassCardShadow, radius: 24, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .frame(minHeight: AppSpacing.homeSheetPrimaryCardMinHeight, alignment: .top)
    }

    private func roadmapStep(index: Int, isCurrent: Bool, title: String, detail: String, isLast: Bool = false) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(isCurrent ? AppColors.inkPrimary : AppColors.inkPrimary.opacity(0.06))
                    .frame(width: 32, height: 32)
                Text("\(index)")
                    .font(.smallLabel)
                    .foregroundStyle(isCurrent ? AppColors.ctaWhite : AppColors.inkSoft)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .strokeBorder(AppColors.inkBorder, lineWidth: 1)
                    .background(Circle().fill(AppColors.ctaWhite))
                    .frame(width: 34, height: 34)
                Image(systemName: "chevron.right")
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary.opacity(0.54))
            }
        }
        .padding(.vertical, AppSpacing.rowItem)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AppColors.inkDivider)
                    .frame(height: 1)
            }
        }
    }
}
