//
//  LiquidGlassTabBar.swift
//  Meridian
//
//  Liquid Glass 浮动 Tab Bar（与 HTML 原型视觉一致）
//  展开：三键胶囊；收拢：右侧单圆，点击恢复 Sheet。
//

import SwiftUI

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: MainTabItem
    /// 0 = 展开（三键胶囊）；1 = 收拢（右侧单圆）
    var collapseProgress: CGFloat
    let onTabTapped: (MainTabItem) -> Void
    /// 点击收拢圆圈时触发——由调用方恢复 Sheet 高度
    let onCollapsedChromeTap: () -> Void

    @Namespace private var selectionNS

    private let tabs: [(item: MainTabItem, icon: String, label: String)] = [
        (.home,       "house.fill",                "Home"),
        (.cashflow,   "creditcard",                "Cash"),
        (.investment, "chart.line.uptrend.xyaxis", "Invest"),
    ]

    private var p: CGFloat { max(0, min(1, collapseProgress)) }

    private var activeIcon: String {
        tabs.first { $0.item == selectedTab }?.icon ?? "house.fill"
    }

    var body: some View {
        ZStack {

            // ── 展开态：三键胶囊 ───────────────────────────────────────
            capsuleBar
                .opacity(Double(1 - p))
                // 收起时从右侧向内缩（非两侧向中心）；展开恢复时配合 offset 形成自右向左展开
                .offset(x: 32 * p)
                .scaleEffect(
                    x: max(0.30, 1 - p * 0.55),
                    y: max(0.86, 1 - p * 0.12),
                    anchor: UnitPoint(x: 1, y: 0.5)
                )
                .blur(radius: p * 5)
                .allowsHitTesting(p < 0.5)
                .frame(maxWidth: .infinity, alignment: .center)

            // ── 收拢态：右侧单圆 ───────────────────────────────────────
            collapseCircle
                .opacity(Double(p))
                .scaleEffect(max(0.30, 0.30 + 0.70 * p), anchor: .trailing)
                .allowsHitTesting(p >= 0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.80), value: p)
        .padding(.horizontal, AppSpacing.tabBarHorizontalInset)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Capsule bar

    private var capsuleBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.item) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(glassBackground(in: Capsule()))
    }

    private func tabButton(_ tab: (item: MainTabItem, icon: String, label: String)) -> some View {
        let isSelected = selectedTab == tab.item
        return Button {
            onTabTapped(tab.item)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.chromeIconMedium)
                    .frame(width: AppSpacing.tabBarIconRowHeight,
                           height: AppSpacing.tabBarIconRowHeight)
                Text(tab.label)
                    .font(.label)
            }
            .foregroundStyle(AppColors.tabBarActiveItem)
            .frame(width: 86, height: AppSpacing.tabBarButtonRowHeight)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppColors.tabBarGlassSelectedTint)
                        .overlay(
                            Capsule()
                                .inset(by: 0.25)
                                .stroke(AppColors.tabBarBorder.opacity(0.75), lineWidth: 0.5)
                        )
                        .matchedGeometryEffect(id: "tab_sel", in: selectionNS)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier(Self.accessibilityIdentifier(for: tab.item))
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selectedTab)
    }

    /// Stable accessibility identifiers consumed by `MeridianUITests`.
    private static func accessibilityIdentifier(for item: MainTabItem) -> String {
        switch item {
        case .home: return "tab_home"
        case .cashflow: return "tab_cashflow"
        case .investment: return "tab_investment"
        case .settings: return "tab_settings"
        }
    }

    // MARK: - Collapse circle

    private var collapseCircle: some View {
        Button(action: onCollapsedChromeTap) {
            Image(systemName: activeIcon)
                .font(.chromeIconMedium)
                .foregroundStyle(AppColors.tabBarActiveItem)
                .frame(
                    width: AppSpacing.tabBarCollapsedCircle,
                    height: AppSpacing.tabBarCollapsedCircle
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .background(glassBackground(in: Circle()))
        .accessibilityLabel("展开导航栏")
    }

    // MARK: - Shared glass background

    private func glassBackground<S: InsettableShape>(in shape: S) -> some View {
        shape
            .fill(AppColors.tabBarGlassBarTint)
            .shadow(color: AppColors.tabBarShadow, radius: 8, x: 0, y: 2)
            .shadow(color: AppColors.tabBarShadow.opacity(0.6), radius: 2, x: 0, y: 0.5)
            .overlay(
                shape
                    .inset(by: 0.25)
                    .stroke(AppColors.tabBarBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Preview

#Preview("Liquid Glass Tab Bar") {
    _LiquidGlassTabBarPreview()
}

private struct _LiquidGlassTabBarPreview: View {
    @State private var selected: MainTabItem = .home
    @State private var collapse: CGFloat = 0

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    Text(collapse < 0.1 ? "展开态" : collapse > 0.9 ? "收拢态" : "过渡中...")
                        .font(.footnoteSemibold)
                        .foregroundStyle(.secondary)

                    Slider(value: $collapse, in: 0...1)
                        .padding(.horizontal, 48)
                        .tint(.blue)
                }
                .padding(.bottom, AppSpacing.lg)

                LiquidGlassTabBar(
                    selectedTab: $selected,
                    collapseProgress: collapse,
                    onTabTapped: { selected = $0 },
                    onCollapsedChromeTap: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                            collapse = 0
                        }
                    }
                )
                .padding(.bottom, 34)
            }
        }
    }
}
