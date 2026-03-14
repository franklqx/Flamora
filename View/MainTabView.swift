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
    @State private var isSimulatorShown = false
    @State private var showSettings = false

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager

    var body: some View {
        ZStack {
            // 全局纯黑背景
            AppBackgroundView()

            // 内容区域
            Group {
                switch selectedTab {
                case 0:
                    JourneyContainerView(isSimulatorShown: $isSimulatorShown)
                case 1:
                    CashflowView()
                case 2:
                    InvestmentView()
                default:
                    JourneyContainerView(isSimulatorShown: $isSimulatorShown)
                }
            }
            .background(Color.clear)
            .transaction { $0.animation = nil }
            // 顶部栏始终使用 safeAreaInset 固定在顶部，不响应滚动隐藏
            .safeAreaInset(edge: .top, spacing: 0) {
                TopHeaderBar(
                    pageTitle: pageTitleFor(selectedTab),
                    leftAction: headerLeftAction,
                    onSettingsTapped: { showSettings = true },
                    isVisible: true
                )
            }
        }
        // 底部导航贴底：safeAreaInset 自动处理安全区，无需手动偏移
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassmorphicTabBar(selectedTab: $selectedTab)
                .allowsHitTesting(true)
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
    }

    private func pageTitleFor(_ tab: Int) -> String {
        switch tab {
        case 0: return isSimulatorShown ? "Simulator" : "Home"
        case 1: return "Cash Flow"
        case 2: return "Investment"
        default: return "Home"
        }
    }

    private var headerLeftAction: HeaderLeftAction {
        switch selectedTab {
        case 0:
            return .flameToggle(isOn: isSimulatorShown, action: {
                isSimulatorShown.toggle()
            })
        case 2:
            return .eye(action: {})
        default:
            return .none
        }
    }
}

#Preview {
    MainTabView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
