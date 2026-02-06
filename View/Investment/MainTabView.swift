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
    @State private var showTabBar = true
    @State private var isSimulatorShown = false

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ZStack {
                // 背景
                Color.black.ignoresSafeArea()

                let shouldShowTabBar = (selectedTab != 0 || !isSimulatorShown) && showTabBar
                let shouldShowHeaderBar = selectedTab == 0
                ? (isSimulatorShown ? showHeaderBar : true)
                : showHeaderBar

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
                .background(Color.black)
                .transaction { $0.animation = nil }
                .onPreferenceChange(HeaderVisibilityPreferenceKey.self) { value in
                    withAnimation(nil) {
                        showHeaderBar = value
                    }
                }
                .onPreferenceChange(TabBarVisibilityPreferenceKey.self) { value in
                    withAnimation(nil) {
                        showTabBar = value
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

                // Tab Bar (浮在最上层)
                if shouldShowTabBar {
                    VStack {
                        Spacer()
                        GlassmorphicTabBar(selectedTab: $selectedTab)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .overlay(alignment: .top) {
                Color.black
                    .frame(height: topInset)
                    .ignoresSafeArea(edges: .top)
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
