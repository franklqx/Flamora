//
//  MainTabView.swift
//  Flamora app
//
//  主导航容器 - 管理 Tab 切换
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showHeaderBar = true
    @State private var isSimulatorShown = false

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let shouldShowTabBar = true
            let shouldShowHeaderBar = selectedTab == 0
            ? (isSimulatorShown ? showHeaderBar : true)
            : showHeaderBar
            ZStack {
                // 背景
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
                .onPreferenceChange(HeaderVisibilityPreferenceKey.self) { value in
                    withAnimation(nil) {
                        showHeaderBar = value
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    TopHeaderBar(
                        userName: "Enxi Lin",
                        leftAction: headerLeftAction,
                        onSettingsTapped: {},
                        isVisible: shouldShowHeaderBar
                    )
                }
            }
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: topInset)
                    .ignoresSafeArea(edges: .top)
            }
            .overlay(alignment: .bottom) {
                if shouldShowTabBar {
                    GlassmorphicTabBar(selectedTab: $selectedTab)
                        .padding(.bottom, bottomInset + 48)
                        .zIndex(10)
                        .allowsHitTesting(true)
                }
            }
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
}
