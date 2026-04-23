//
//  ReportViews.swift
//  Flamora app
//
//  Shared story renderer plus weekly/monthly/annual/issue-zero wrappers.
//

import SwiftUI

struct ReportStoryHostView: View {
    let report: ReportSnapshot

    @Environment(\.dismiss) private var dismiss
    @State private var currentStoryIndex = 0
    @State private var hasMarkedViewed = false

    var body: some View {
        StoryContainer(
            stories: report.stories,
            currentStoryIndex: $currentStoryIndex,
            onDismiss: dismiss.callAsFunction
        )
        .task {
            guard !hasMarkedViewed, report.viewedAt == nil else { return }
            hasMarkedViewed = true
            try? await APIService.shared.markReportViewed(id: report.id)
        }
    }
}

struct WeeklyReportView: View {
    let report: ReportSnapshot

    var body: some View {
        ReportStoryHostView(report: report)
    }
}

struct MonthlyReportView: View {
    let report: ReportSnapshot

    var body: some View {
        ReportStoryHostView(report: report)
    }
}

struct IssueZeroView: View {
    let report: ReportSnapshot

    var body: some View {
        ReportStoryHostView(report: report)
    }
}

struct AnnualReportView: View {
    let report: ReportSnapshot

    var body: some View {
        ReportStoryHostView(report: report)
    }
}

struct ReportFeedRow: View {
    let item: ReportFeedItem
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm + 2)
                        .fill(iconBackground)
                        .frame(width: 38, height: 38)

                    Image(systemName: item.kind.systemImage)
                        .font(.footnoteSemibold)
                        .foregroundStyle(iconForeground)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(item.title)
                            .font(.inlineLabel)
                            .foregroundStyle(AppColors.inkPrimary)

                        if item.isUnread {
                            Text("NEW")
                                .font(.miniLabel)
                                .foregroundStyle(AppColors.ctaWhite)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.success))
                        }
                    }

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineLimit(2)

                    Text(item.periodLabel)
                        .font(.miniLabel)
                        .foregroundStyle(AppColors.inkFaint)
                        .tracking(AppTypography.Tracking.miniUppercase)
                        .textCase(.uppercase)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkFaint)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.sm + 2)
        }
        .buttonStyle(.plain)
    }

    private var iconBackground: Color {
        switch item.kind {
        case .weekly: return AppColors.budgetNeedsBlue.opacity(0.12)
        case .monthly: return AppColors.success.opacity(0.12)
        case .annual: return AppColors.budgetWantsPurple.opacity(0.12)
        case .issueZero: return AppColors.warning.opacity(0.12)
        }
    }

    private var iconForeground: Color {
        switch item.kind {
        case .weekly: return AppColors.budgetNeedsBlue
        case .monthly: return AppColors.success
        case .annual: return AppColors.budgetWantsPurple
        case .issueZero: return AppColors.warning
        }
    }
}

struct StoryContainer: View {
    let stories: [StoryPayload]
    @Binding var currentStoryIndex: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            activeBackground
                .ignoresSafeArea()

            TabView(selection: $currentStoryIndex) {
                ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                    StorySlideView(story: story)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            StoryTapZones(
                currentStoryIndex: $currentStoryIndex,
                storyCount: stories.count,
                onDismiss: onDismiss
            )

            VStack(spacing: 0) {
                StoryProgressSegments(total: stories.count, current: currentStoryIndex)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.top, AppSpacing.lg)

                Spacer()

                StoryDotIndicators(total: stories.count, current: currentStoryIndex)
                    .padding(.bottom, AppSpacing.xl + AppSpacing.md)
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(false)
    }

    @ViewBuilder
    private var activeBackground: some View {
        let background = stories.indices.contains(currentStoryIndex) ? stories[currentStoryIndex].background : .dark

        switch background {
        case .purple:
            StoryBackgroundView(colors: [Color(hex: "#A78BFA").opacity(0.22)])
        case .green:
            StoryBackgroundView(colors: [AppColors.success.opacity(0.20)])
        case .amber:
            StoryBackgroundView(colors: [Color(hex: "#FCD34D").opacity(0.18)])
        case .blue:
            StoryBackgroundView(colors: [Color(hex: "#93C5FD").opacity(0.18)])
        case .dark:
            AppColors.backgroundPrimary
        }
    }
}

private struct StoryBackgroundView: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary

            RadialGradient(
                colors: colors + [AppColors.backgroundPrimary.opacity(0.92), AppColors.backgroundPrimary],
                center: .topLeading,
                startRadius: 80,
                endRadius: 520
            )
        }
    }
}

private struct StorySlideView: View {
    let story: StoryPayload
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label = story.label, !label.isEmpty {
                Text(label)
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                    .textCase(.uppercase)
                    .padding(.bottom, AppSpacing.lg)
            } else {
                Spacer().frame(height: 16)
            }

            Spacer(minLength: 0)

            switch story.layout {
            case .hero, .headline:
                heroSection
            case .insight:
                insightSection
            case .grid:
                gridSection
            case .cta:
                ctaSection
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, 44)
        .padding(.bottom, AppSpacing.xl * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let heroText = story.heroText {
                Text(heroText)
                    .font(heroFont)
                    .kerning(story.heroFont == .storyHero ? -2 : 0)
                    .foregroundStyle(heroForegroundStyle)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let heroSubtext = story.heroSubtext {
                Text(heroSubtext)
                    .font(.supportingText)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let badge = story.badgeText {
                Text(badge)
                    .font(.smallLabel)
                    .foregroundStyle(AppColors.ctaWhite)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.success))
            }

            storyRows
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if let heroText = story.heroText {
                Text(heroText)
                    .font(.h2)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(story.gridItems) { item in
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(item.label)
                            .font(.footnoteSemibold)
                            .foregroundStyle(AppColors.textSecondary)
                            .tracking(AppTypography.Tracking.cardHeader)
                            .textCase(.uppercase)

                        Text(item.value)
                            .font(.cardFigurePrimary)
                            .foregroundStyle(AppColors.textPrimary)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(AppColors.surfaceBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
            }
        }
    }

    private var insightSection: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: AppColors.gradientFire,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let insightText = story.insightText {
                    Text(insightText)
                        .font(.h3)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let source = story.insightSource {
                    Text(source)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var ctaSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            heroSection

            if let ctaLabel = story.ctaLabel {
                Button {
                    dismiss()
                } label: {
                    Text(ctaLabel)
                        .font(.sheetPrimaryButton)
                        .foregroundStyle(AppColors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.md)
            }
        }
    }

    private var storyRows: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(story.rows) { row in
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Text(row.label)
                        .font(.inlineLabel)
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.value)
                            .font(.footnoteSemibold)
                            .foregroundStyle(rowStyle(row.valueStyle))
                            .multilineTextAlignment(.trailing)

                        if let note = row.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }

    private var heroFont: Font {
        switch story.heroFont ?? .storyHero {
        case .storyHero: return .storyHero
        case .h1: return .h1
        case .h2: return .h2
        case .cardFigurePrimary: return .cardFigurePrimary
        }
    }

    private var heroForegroundStyle: AnyShapeStyle {
        switch story.heroStyle ?? .primary {
        case .gradientFire:
            return AnyShapeStyle(
                LinearGradient(
                    colors: AppColors.gradientFire,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .success:
            return AnyShapeStyle(AppColors.success)
        case .warning:
            return AnyShapeStyle(AppColors.warning)
        case .error:
            return AnyShapeStyle(AppColors.error)
        case .primary:
            return AnyShapeStyle(AppColors.textPrimary)
        case .secondary:
            return AnyShapeStyle(AppColors.textSecondary)
        }
    }

    private func rowStyle(_ style: StoryHeroStyle?) -> AnyShapeStyle {
        switch style ?? .primary {
        case .gradientFire:
            AnyShapeStyle(
                LinearGradient(colors: AppColors.gradientFire, startPoint: .leading, endPoint: .trailing)
            )
        case .success:
            AnyShapeStyle(AppColors.success)
        case .warning:
            AnyShapeStyle(AppColors.warning)
        case .error:
            AnyShapeStyle(AppColors.error)
        case .primary:
            AnyShapeStyle(AppColors.textPrimary)
        case .secondary:
            AnyShapeStyle(AppColors.textSecondary)
        }
    }
}

struct StoryProgressSegments: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index <= current ? AppColors.textPrimary : AppColors.overlayWhiteStroke)
                    .frame(maxWidth: .infinity)
                    .frame(height: 2)
            }
        }
    }
}

struct StoryDotIndicators: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Capsule()
                    .fill(index == current ? AppColors.textPrimary : AppColors.overlayWhiteForegroundSoft)
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
    }
}

struct StoryTapZones: View {
    @Binding var currentStoryIndex: Int
    let storyCount: Int
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: geo.size.width * 0.30)
                    .onTapGesture {
                        if currentStoryIndex == 0 {
                            onDismiss()
                        } else {
                            withAnimation(.easeOut(duration: 0.18)) {
                                currentStoryIndex = max(0, currentStoryIndex - 1)
                            }
                        }
                    }

                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: geo.size.width * 0.70)
                    .onTapGesture {
                        if currentStoryIndex >= max(storyCount - 1, 0) {
                            onDismiss()
                        } else {
                            withAnimation(.easeOut(duration: 0.18)) {
                                currentStoryIndex = min(storyCount - 1, currentStoryIndex + 1)
                            }
                        }
                    }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Report Story") {
    WeeklyReportView(report: .previewWeekly)
}
