//
//  HomeBottomSheet.swift
//  Flamora app
//
//  底部白色可拖动 Sheet，三个 Tab 共用。
//  上方圆角、下方平直边；由 MainTabView 贴屏底并忽略底部安全区，避免 Home Indicator 带露出背景色。
//

import SwiftUI

private let sheetShape = UnevenRoundedRectangle(
    topLeadingRadius: AppRadius.xl,
    bottomLeadingRadius: 0,
    bottomTrailingRadius: 0,
    topTrailingRadius: AppRadius.xl
)

struct HomeBottomSheet: View {
    /// 主内容区高度（从顶部把手到底部内容结束），不含底部安全区 / chrome 预留。
    let contentHeight: CGFloat
    /// 仍属于 sheet 本体的底部延伸区，用来让整张 sheet 从屏幕底部开始。
    let bottomInset: CGFloat
    let selectedTab: MainTabItem
    let sheetDragGesture: AnyGesture<DragGesture.Value>
    let dragProgress: CGFloat
    @Environment(PlaidManager.self) private var plaidManager

    private let handleHeight: CGFloat = 24

    private var totalHeight: CGFloat {
        contentHeight + bottomInset
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Capsule()
                    .fill(AppColors.surfaceBorder)
                    .frame(width: 36, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: handleHeight)
            .contentShape(Rectangle())
            .highPriorityGesture(sheetDragGesture)
            .overlay(alignment: .center) {
                let labelOpacity = max(0, min(1, (dragProgress - 0.72) / 0.28))
                if labelOpacity > 0 {
                    Text(backLabelText)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textSecondary)
                        .opacity(labelOpacity)
                        .allowsHitTesting(false)
                }
            }

            Group {
                switch selectedTab {
                case .home:
                    HomeRoadmapContent()
                case .cashflow:
                    if plaidManager.hasLinkedBank {
                        CashflowView()
                    } else {
                        CashUnconnectedContent()
                    }
                case .investment:
                    InvestmentSheetContent()
                case .settings:
                    SettingsView(isEmbeddedInSheet: true)
                }
            }
            .id(selectedTab)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity, alignment: .top)
            // 用 safeAreaInset 为 Tab/Home Indicator 留白；避免对外层加 bottom padding 时 ScrollView 被提前裁切一条线。
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: bottomInset)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight, alignment: .top)
        .background(
            sheetShape
                .fill(
                    LinearGradient(
                        colors: [AppColors.shellBg1, AppColors.shellBg2],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .clipShape(sheetShape)
        .shadow(color: AppColors.glassCardShadow, radius: 18, y: -4)
    }

    private var backLabelText: String {
        switch selectedTab {
        case .cashflow: return "Back to Cash Flow"
        case .investment: return "Back to Investment"
        default: return "Back to Home"
        }
    }
}

#Preview("Home") {
    HomeBottomSheetPreview(selectedTab: .home)
        .environment(PlaidManager.shared)
}

#Preview("Cash") {
    HomeBottomSheetPreview(selectedTab: .cashflow)
        .environment(PlaidManager.shared)
}

#Preview("Investment") {
    HomeBottomSheetPreview(selectedTab: .investment)
        .environment(PlaidManager.shared)
}

private struct HomeBottomSheetPreview: View {
    let selectedTab: MainTabItem

    var body: some View {
        GeometryReader { proxy in
            let sheetBottomExtension = max(0, AppSpacing.homeSheetTopOverlap - AppSpacing.md - 2)
            let bottomInset = proxy.safeAreaInsets.bottom + 2 + sheetBottomExtension
            let sheetTotal = max(0, proxy.size.height - AppSpacing.homeSheetTopOverlap)
            let contentHeight = max(0, sheetTotal - bottomInset)

            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HomeBottomSheet(
                        contentHeight: contentHeight,
                        bottomInset: bottomInset,
                        selectedTab: selectedTab,
                        sheetDragGesture: AnyGesture(DragGesture()),
                        dragProgress: 0
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

