//
//  MainTabView.swift
//  Flamora app
//
//  主导航容器 - 管理 Tab 切换
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showTabBar = true

    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()

            // 内容区域
            Group {
                switch selectedTab {
                case 0:
                    JourneyContainerView()  // 使用新的容器视图，支持滑动切换
                case 1:
                    CashflowView()
                case 2:
                    InvestmentView()
                default:
                    JourneyContainerView()
                }
            }
            .onPreferenceChange(TabBarVisibilityPreferenceKey.self) { value in
                showTabBar = value
            }

            // Tab Bar (浮在最上层)
            if showTabBar {
                VStack {
                    Spacer()
                    GlassmorphicTabBar(selectedTab: $selectedTab)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

#Preview {
    MainTabView()
}
