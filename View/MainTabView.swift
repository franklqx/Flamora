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
    @State private var tabBeforeSimulator = 0
    @State private var isSimulatorShown = false
    @State private var simulatorDisplayState: SimulatorDisplayState = .overview
    @State private var showSettings = false
    @State private var flipAngle: Double = 0
    @State private var journeyCashflowSecondary: CashflowJourneyDestination? = nil

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager

    var body: some View {
        ZStack(alignment: .top) {
            AppBackgroundView()

            // 内容区域 — 参与翻转，header 不参与
            ZStack {
                if isSimulatorShown {
                    AppColors.backgroundPrimary.ignoresSafeArea()
                        .zIndex(1)
                    SimulatorView(
                        displayState: $simulatorDisplayState,
                        bottomPadding: 0,
                        isFireOn: true,
                        onFireToggle: flipPage
                    )
                    .zIndex(2)
                } else {
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
                }
            }
            // 用透明占位把内容推到 header 下方
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: TopHeaderBar.height)
            }
            .rotation3DEffect(
                .degrees(flipAngle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.3
            )
            .opacity(abs(flipAngle) >= 90 ? 0 : 1)

            // 静态顶部导航 — 永远不参与翻转
            TopHeaderBar(
                pageTitle: pageTitleFor(selectedTab),
                leftAction: headerLeftAction,
                onSettingsTapped: { showSettings = true },
                isVisible: !isSimulatorShown || simulatorDisplayState != .loading
            )
            .zIndex(10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassmorphicTabBar(selectedTab: $selectedTab)
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

    private var showTabBar: Bool {
        !isSimulatorShown
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
        return .flame(isActive: isSimulatorShown, action: flipPage)
    }

    private func flipPage() {
        let opening = !isSimulatorShown
        // 第一阶段：当前页翻转消失
        withAnimation(.easeIn(duration: 0.2)) {
            flipAngle = 90
        }
        // 中点切换内容，再翻转出来
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if opening {
                tabBeforeSimulator = selectedTab
                isSimulatorShown = true
            } else {
                isSimulatorShown = false
                selectedTab = tabBeforeSimulator
                simulatorDisplayState = .overview
            }
            flipAngle = -90
            // 第二阶段：新页翻转进入
            withAnimation(.easeOut(duration: 0.2)) {
                flipAngle = 0
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
