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
    /// Vertical scrub feedback (0...1) while dragging on the tab bar.
    let onCollapseScrubChanged: (CGFloat) -> Void
    /// Final vertical scrub progress (0...1) on drag end.
    let onCollapseScrubEnded: (CGFloat) -> Void
    /// Horizontal scrub target tab while dragging.
    let onTabScrubbed: (MainTabItem) -> Void

    @Namespace private var tabIndicator
    @State private var dragStartCollapseProgress: CGFloat?
    @State private var dragStartTabIndex: Int?
    @State private var activeDragAxis: Axis?
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var longPressedTab: MainTabItem?

    private let tabs: [(item: MainTabItem, icon: String, label: String)] = [
        (.home, "house.fill", "Home"),
        (.cashflow, "creditcard", "Cash"),
        (.investment, "chart.line.uptrend.xyaxis", "Invest"),
    ]

    private var clampedProgress: CGFloat {
        max(0, min(1, collapseProgress))
    }

    private var collapsedTabSpec: (icon: String, label: String) {
        tabs.first(where: { $0.item == selectedTab }).map { ($0.icon, $0.label) } ?? ("house.fill", "Home")
    }

    private var collapsedAccessibilityLabel: String {
        "Expand \(collapsedTabSpec.label)"
    }

    var body: some View {
        GeometryReader { geo in
            let tabWidth = max(1, geo.size.width / CGFloat(tabs.count))

            ZStack(alignment: .trailing) {
                ZStack {
                    Capsule()
                        .fill(Color.clear)
                        .glassEffect(Glass.regular.tint(AppColors.tabBarGlassBarTint), in: Capsule())

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    Color.white.opacity(0.04),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 0) {
                            ForEach(tabs.indices, id: \.self) { index in
                                let tab = tabs[index]
                                GlassTabButton(
                                    icon: tab.icon,
                                    label: tab.label,
                                    isSelected: selectedTab == tab.item,
                                    namespace: tabIndicator,
                                    swipeInfluence: swipeInfluence(for: index, tabWidth: tabWidth),
                                    isLongPressed: longPressedTab == tab.item,
                                    collapseOpacity: collapseTabOpacity(for: index)
                                ) {
                                    onTabTapped(tab.item)
                                }
                                .offset(x: collapseTabOffset(for: index))
                                .onLongPressGesture(
                                    minimumDuration: 0.16,
                                    maximumDistance: 20,
                                    pressing: { pressing in
                                        withAnimation(.easeInOut(duration: 0.14)) {
                                            longPressedTab = pressing ? tab.item : nil
                                        }
                                    },
                                    perform: {}
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, AppSpacing.xs)
                    }
                }
                .overlay(
                    Capsule()
                        .stroke(AppColors.tabBarBorder, lineWidth: 1)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppColors.tabBarHighlight,
                                    Color.clear,
                                    Color.white.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                )
                .tabBarShadow()
                .scaleEffect(
                    x: 1 - 0.10 * clampedProgress,
                    y: 1 - 0.02 * clampedProgress,
                    anchor: .trailing
                )
                .offset(x: 22 * clampedProgress)
                .opacity(Double(1 - clampedProgress))
                .allowsHitTesting(clampedProgress < 0.5)

                Button(action: onCollapsedChromeTap) {
                    Image(systemName: collapsedTabSpec.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.94))
                        .frame(width: AppSpacing.tabBarCollapsedCircle, height: AppSpacing.tabBarCollapsedCircle)
                        .background {
                            Circle()
                                .fill(Color.clear)
                                .glassEffect(Glass.regular.tint(AppColors.tabBarCollapsedGlassTint), in: Circle())
                        }
                        .overlay {
                            Circle()
                                .stroke(AppColors.tabBarHighlight, lineWidth: 0.8)
                        }
                        .shadow(color: Color(hex: "#101846").opacity(0.18), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(collapsedAccessibilityLabel)
                .opacity(Double(clampedProgress))
                .scaleEffect(0.90 + 0.10 * clampedProgress)
                .offset(y: -1)
                .allowsHitTesting(clampedProgress >= 0.5)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if dragStartCollapseProgress == nil {
                            dragStartCollapseProgress = clampedProgress
                        }
                        if dragStartTabIndex == nil {
                            dragStartTabIndex = selectedTab.rawValue
                        }

                        if activeDragAxis == nil {
                            activeDragAxis = abs(value.translation.width) > abs(value.translation.height) + 6
                                ? .horizontal
                                : .vertical
                        }

                        guard let axis = activeDragAxis else { return }

                        if axis == .vertical, let start = dragStartCollapseProgress {
                            let next = max(0, min(1, start + (value.translation.height / 132)))
                            onCollapseScrubChanged(next)
                            horizontalDragOffset = 0
                            return
                        }

                        guard axis == .horizontal else { return }

                        horizontalDragOffset = value.translation.width

                        if let start = dragStartCollapseProgress {
                            onCollapseScrubChanged(start)
                        }

                        guard clampedProgress < 0.55, let startIndex = dragStartTabIndex else { return }
                        let shift = Int(round((-value.translation.width) / tabWidth))
                        let targetIndex = max(0, min(tabs.count - 1, startIndex + shift))
                        onTabScrubbed(tabs[targetIndex].item)
                    }
                    .onEnded { value in
                        let endedAxis = activeDragAxis

                        defer {
                            dragStartCollapseProgress = nil
                            dragStartTabIndex = nil
                            activeDragAxis = nil
                            withAnimation(.easeOut(duration: 0.18)) {
                                horizontalDragOffset = 0
                                longPressedTab = nil
                            }
                        }

                        guard endedAxis == .vertical else { return }
                        let start = dragStartCollapseProgress ?? clampedProgress
                        let final = max(0, min(1, start + (value.predictedEndTranslation.height / 132)))
                        onCollapseScrubEnded(final)
                    }
            )
        }
        .frame(height: max(AppSpacing.tabBarCollapsedCircle, AppSpacing.tabBarButtonRowHeight + (AppSpacing.xs * 2)))
        .padding(.horizontal, AppSpacing.tabBarHorizontalInset)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.24), value: clampedProgress)
    }

    private func collapseTabOffset(for index: Int) -> CGFloat {
        let order = CGFloat(tabs.count - 1 - index)
        return order * AppSpacing.sm * 0.75 * clampedProgress
    }

    private func collapseTabOpacity(for index: Int) -> CGFloat {
        guard clampedProgress > 0.72 else { return 1 }
        let t = min(1, (clampedProgress - 0.72) / 0.28)
        let leftWeight = CGFloat(tabs.count - 1 - index) / max(1, CGFloat(tabs.count - 1))
        return 1 - t * leftWeight * 0.92
    }

    private func swipeInfluence(for index: Int, tabWidth: CGFloat) -> CGFloat {
        guard tabWidth > 0 else { return 0 }
        let focus = CGFloat(selectedTab.rawValue) - (horizontalDragOffset / tabWidth)
        let distance = abs(CGFloat(index) - focus)
        return max(0, 1 - min(1, distance))
    }
}

private struct GlassTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let swipeInfluence: CGFloat
    let isLongPressed: Bool
    /// 收拢动画中随左侧优先级的透明度（与主条 opacity 叠加）。
    var collapseOpacity: CGFloat = 1
    let action: () -> Void

    private var shouldShowPill: Bool {
        isSelected || swipeInfluence > 0.12 || isLongPressed
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.chromeIconMedium)
                    .frame(height: AppSpacing.tabBarIconRowHeight)
                Text(label)
                    .font(.label)
            }
            .foregroundStyle(isSelected ? AppColors.tabBarActiveItem : AppColors.tabBarInactiveLabel)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.tabBarButtonRowHeight)
            .opacity(Double(collapseOpacity))
            .scaleEffect(isLongPressed ? 0.97 : 1)
            .background {
                if shouldShowPill {
                    Capsule()
                        .fill(Color.clear)
                        .glassEffect(selectionGlass(), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(
                                    Color.white.opacity(isLongPressed ? 0.46 : 0.30),
                                    lineWidth: isLongPressed ? 0.9 : 0.6
                                )
                        }
                        .if(isSelected) { view in
                            view.matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.14), value: isLongPressed)
    }

    private func selectionGlass() -> Glass {
        if isLongPressed {
            return Glass.regular.tint(AppColors.tabBarGlassSelectedTint.opacity(0.95))
        }
        if isSelected {
            return Glass.regular.tint(AppColors.tabBarGlassSelectedTint)
        }
        let strength = Double(max(0.10, min(0.6, swipeInfluence * 0.5)))
        return Glass.regular.tint(AppColors.tabBarGlassSelectedTint.opacity(strength))
    }
}

private extension View {
    @ViewBuilder
    func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition {
            transform(self)
        } else {
            self
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
                onCollapsedChromeTap: {},
                onCollapseScrubChanged: { _ in },
                onCollapseScrubEnded: { _ in },
                onTabScrubbed: { _ in }
            )
        }
    }
}
