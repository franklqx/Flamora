//
//  GlassmorphicTabBar.swift
//  Flamora app
//
//  底部 Tab Bar 外观（三键胶囊 / 可选收拢为单圆）。由 `MainTabView` 内 `MainTabBarInset` 贴底挂载；
//  `collapseProgress` 随 Sheet 低于默认高度时增大（仅形态，不侵入 Tab 安全区）。
//

import SwiftUI

enum MainTabItem: Int {
    case home = 0
    case cashflow = 1
    case investment = 2
    case settings = 3
}

struct GlassmorphicTabBar: View {
    @Binding var selectedTab: MainTabItem
    /// 0 = 三键展开；1 = 仅右侧单圆（当前 Tab）
    var collapseProgress: CGFloat
    let onTabTapped: (MainTabItem) -> Void
    /// Sheet 已收起到 default 以下时点击单圆恢复白卡高度
    let onCollapsedChromeTap: () -> Void

    @Namespace private var tabIndicator

    private let tabs: [(item: MainTabItem, icon: String, label: String)] = [
        (.home, "house.fill", "Home"),
        (.cashflow, "creditcard", "Cash"),
        (.investment, "chart.line.uptrend.xyaxis", "Invest"),
    ]

    private var clampedProgress: CGFloat {
        max(0, min(1, collapseProgress))
    }

    private var collapsedAccessibilityLabel: String {
        let name = tabs.first { $0.item == selectedTab }?.label ?? "Home"
        return "Expand \(name)"
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { index in
                    GlassTabButton(
                        item: tabs[index].item,
                        icon: tabs[index].icon,
                        label: tabs[index].label,
                        isSelected: selectedTab == tabs[index].item,
                        namespace: tabIndicator
                    ) {
                        onTabTapped(tabs[index].item)
                    }
                    .offset(x: collapseTabOffset(for: index))
                }
            }
            .padding(.horizontal, AppSpacing.xxs)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .scaleEffect(
                x: 1 - 0.16 * clampedProgress,
                y: 1 - 0.05 * clampedProgress,
                anchor: .trailing
            )
            .offset(x: 28 * clampedProgress)
            .opacity(Double(1 - clampedProgress))
            .allowsHitTesting(clampedProgress < 0.5)

            Button(action: onCollapsedChromeTap) {
                Image(systemName: "house.fill")
                    .font(.chromeIconMedium)
                    .foregroundStyle(Color.white.opacity(0.96))
                    .frame(width: AppSpacing.tabBarCollapsedCircle, height: AppSpacing.tabBarCollapsedCircle)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#1C2D83"), Color(hex: "#16236A")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#101846").opacity(0.42), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(collapsedAccessibilityLabel)
            .opacity(Double(clampedProgress))
            .scaleEffect(0.88 + 0.12 * clampedProgress)
            .offset(y: -10)
            .allowsHitTesting(clampedProgress >= 0.5)
        }
        .padding(.horizontal, AppSpacing.tabBarHorizontalInset)
        .padding(.bottom, 0)
        .padding(.top, AppSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.easeInOut(duration: 0.28), value: clampedProgress)
    }

    /// 左侧 Tab 先向右收拢，强化「从左向右」进右侧单圆的观感（右手拇指更易够到）。
    private func collapseTabOffset(for index: Int) -> CGFloat {
        let order = CGFloat(tabs.count - 1 - index)
        return order * AppSpacing.sm * clampedProgress
    }
}

private struct GlassTabButton: View {
    let item: MainTabItem
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.chromeIconMedium)
                    .frame(height: 28)
                Text(label)
                    .font(.label)
            }
            .foregroundStyle(isSelected ? AppColors.inkPrimary : AppColors.tabBarInactiveLabel)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppColors.tabBarActiveItem)
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab_\(identifierSuffix)")
    }

    private var identifierSuffix: String {
        switch item {
        case .home: return "home"
        case .cashflow: return "cashflow"
        case .investment: return "investment"
        case .settings: return "settings"
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack {
            Spacer()
            GlassmorphicTabBar(
                selectedTab: .constant(.home),
                collapseProgress: 0,
                onTabTapped: { _ in },
                onCollapsedChromeTap: {}
            )
        }
    }
}
