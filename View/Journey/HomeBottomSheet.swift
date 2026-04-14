//
//  HomeBottomSheet.swift
//  Flamora app
//
//  底部白色可拖动 Sheet，三个 Tab 共用。
//  上方圆角、下方平直边；壳底对齐主内容 Safe Area 底（Tab 上沿），不单独向下延伸色块。
//

import SwiftUI

private let sheetShape = UnevenRoundedRectangle(
    topLeadingRadius: AppRadius.xl,
    bottomLeadingRadius: 0,
    bottomTrailingRadius: 0,
    topTrailingRadius: AppRadius.xl
)

struct HomeBottomSheet: View {
    let height: CGFloat
    let selectedTab: MainTabItem
    let sheetDragGesture: AnyGesture<DragGesture.Value>
    let dragProgress: CGFloat
    @Environment(PlaidManager.self) private var plaidManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Capsule()
                    .fill(AppColors.surfaceBorder)
                    .frame(width: 36, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 24)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
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
        .frame(maxHeight: .infinity, alignment: .bottom)
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
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        HomeBottomSheet(
            height: 580,
            selectedTab: .home,
            sheetDragGesture: AnyGesture(DragGesture()),
            dragProgress: 0
        )
        .offset(y: -AppSpacing.homeSheetTopOverlap)
    }
    .environment(PlaidManager.shared)
}

#Preview("Cash") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        HomeBottomSheet(
            height: 480,
            selectedTab: .cashflow,
            sheetDragGesture: AnyGesture(DragGesture()),
            dragProgress: 0
        )
        .offset(y: -AppSpacing.homeSheetTopOverlap)
    }
    .environment(PlaidManager.shared)
}

#Preview("Investment") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        HomeBottomSheet(
            height: 480,
            selectedTab: .investment,
            sheetDragGesture: AnyGesture(DragGesture()),
            dragProgress: 0
        )
        .offset(y: -AppSpacing.homeSheetTopOverlap)
    }
    .environment(PlaidManager.shared)
}
