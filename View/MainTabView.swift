//
//  MainTabView.swift
//  Flamora app
//
//  主导航容器 - 管理 Tab 切换
//

import SwiftUI
internal import Auth

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var tabBeforeSimulator = 0          // 记住进入 Simulator 前所在的 Tab
    @State private var isSimulatorShown = false
    @State private var simulatorDisplayState: SimulatorDisplayState = .overview
    @State private var showSettings = false
    /// Journey 卡片直达二级页（不切到 Cash Flow Tab）
    @State private var journeyCashflowSecondary: CashflowJourneyDestination? = nil

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager

    var body: some View {
        ZStack(alignment: .top) {
            // 全局纯黑背景
            AppBackgroundView()

            // 内容区域
            Group {
                switch selectedTab {
                case 0:
                    JourneyContainerView(
                        onFireTapped: flipPage,
                        onInvestmentTapped: { selectedTab = 2 },
                        onOpenCashflowDestination: { journeyCashflowSecondary = $0 }
                    )
                case 1:
                    CashflowView()
                case 2:
                    InvestmentView()
                default:
                    JourneyContainerView(
                        onFireTapped: flipPage,
                        onInvestmentTapped: { selectedTab = 2 },
                        onOpenCashflowDestination: { journeyCashflowSecondary = $0 }
                    )
                }
            }
            .background(Color.clear)
            .transaction { $0.animation = nil }
            .safeAreaInset(edge: .top, spacing: 0) {
                TopHeaderBar(
                    pageTitle: pageTitleFor(selectedTab),
                    leftAction: headerLeftAction,
                    onSettingsTapped: { showSettings = true },
                    isVisible: true
                )
            }

            // 全局 Simulator 覆盖层 — 从任意 Tab 打开，覆盖全部内容
            if isSimulatorShown {
                Color.black.ignoresSafeArea()
                    .zIndex(1)

                SimulatorView(
                    displayState: $simulatorDisplayState,
                    bottomPadding: 0,
                    isFireOn: true,
                    onFireToggle: flipPage
                )
                .safeAreaInset(edge: .top, spacing: 0) {
                    TopHeaderBar(
                        pageTitle: "Simulator",
                        leftAction: headerLeftAction,
                        onSettingsTapped: { showSettings = true },
                        isVisible: simulatorDisplayState != .loading
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
                .zIndex(2)
            }
        }
        // 底部导航：用 opacity 控制显隐，避免 view 销毁/重建导致 glassEffect tint 重置
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassmorphicTabBar(
                selectedTab: $selectedTab,
                isSimulatorShown: isSimulatorShown,
                onFlameToggle: flipPage
            )
            .ignoresSafeArea(edges: .bottom)
            .opacity(showTabBar ? 1 : 0)
            .allowsHitTesting(showTabBar)
        }
        .ignoresSafeArea(.keyboard, edges: .all)
        .fullScreenCover(isPresented: Binding(
            get: { plaidManager.showBudgetSetup },
            set: { plaidManager.showBudgetSetup = $0 }
        )) {
            BudgetSetupView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(subscriptionManager)
                .environment(plaidManager)
        }
        .fullScreenCover(item: $journeyCashflowSecondary) { destination in
            switch destination {
            case .totalSpending:
                TotalSpendingAnalysisDetailView(data: MockData.totalSpendingDetail)
            case .savingsOverview:
                SavingsTargetDetailView2()
            }
        }
    }

    // Simulator overview 时显示火焰 FAB，loading/results 时隐藏整个 tab bar
    private var showTabBar: Bool {
        if isSimulatorShown {
            if case .overview = simulatorDisplayState { return true }
            return false
        }
        return true
    }

    private func pageTitleFor(_ tab: Int) -> String {
        if isSimulatorShown { return "Simulator" }
        switch tab {
        case 0: return "Home"
        case 1: return "Cash Flow"
        case 2: return "Investment"
        default: return "Home"
        }
    }

    private var headerLeftAction: HeaderLeftAction {
        if isSimulatorShown, case .results = simulatorDisplayState {
            return .close(action: { simulatorDisplayState = .overview })
        }
        switch selectedTab {
        case 2:
            return .eye(action: {})
        default:
            return .none
        }
    }

    private func flipPage() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if isSimulatorShown {
                // 关闭：恢复之前的 Tab
                isSimulatorShown = false
                selectedTab = tabBeforeSimulator
                simulatorDisplayState = .overview
            } else {
                // 打开：记录当前 Tab
                tabBeforeSimulator = selectedTab
                isSimulatorShown = true
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
