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
    @State private var dragTranslation: CGSize = .zero

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
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                HStack(spacing: 0) {
                    ForEach(tabs.indices, id: \.self) { index in
                        let influence = jellyInfluence(for: index, width: geo.size.width)
                        GlassTabButton(
                            icon: tabs[index].icon,
                            label: tabs[index].label,
                            isSelected: selectedTab == tabs[index].item,
                            namespace: tabIndicator,
                            jellyInfluence: influence,
                            dragTranslation: dragTranslation
                        ) {
                            onTabTapped(tabs[index].item)
                        }
                        .offset(x: collapseTabOffset(for: index))
                    }
                }
                .padding(.horizontal, AppSpacing.xxs)
                .padding(.vertical, AppSpacing.xs)
                .background { Capsule().fill(.clear) }
                .glassEffect(.regular.interactive(), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColors.tabBarBorder.opacity(0.55), lineWidth: 0.75)
                )
                .tabBarShadow()
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
                .offset(y: -2)
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
                            activeDragAxis = abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
                        }
                        dragTranslation = value.translation

                        guard let axis = activeDragAxis else { return }

                        if axis == .vertical, let start = dragStartCollapseProgress {
                            let next = max(0, min(1, start + (value.translation.height / 120)))
                            onCollapseScrubChanged(next)
                            return
                        }

                        guard axis == .horizontal else { return }
                        if let start = dragStartCollapseProgress {
                            // Keep existing collapse state when doing horizontal tab scrub.
                            onCollapseScrubChanged(start)
                        }

                        guard clampedProgress < 0.55, let startIndex = dragStartTabIndex else { return }
                        let shift = Int(round((-value.translation.width) / max(1, geo.size.width / CGFloat(tabs.count))))
                        let targetIndex = max(0, min(tabs.count - 1, startIndex + shift))
                        onTabScrubbed(tabs[targetIndex].item)
                    }
                    .onEnded { value in
                        defer {
                            dragStartCollapseProgress = nil
                            dragStartTabIndex = nil
                            activeDragAxis = nil
                            withAnimation(.interpolatingSpring(stiffness: 240, damping: 16)) {
                                dragTranslation = .zero
                            }
                        }
                        guard activeDragAxis == .vertical else {
                            onCollapseScrubEnded(clampedProgress)
                            return
                        }
                        let start = dragStartCollapseProgress ?? clampedProgress
                        let final = max(0, min(1, start + (value.predictedEndTranslation.height / 120)))
                        onCollapseScrubEnded(final)
                    }
            )
        }
        .frame(height: max(AppSpacing.tabBarCollapsedCircle, AppSpacing.tabBarButtonRowHeight + (AppSpacing.xs * 2)))
        .padding(.horizontal, AppSpacing.tabBarHorizontalInset)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.easeInOut(duration: 0.28), value: clampedProgress)
    }

    /// 左侧 Tab 先向右收拢，强化「从左向右」进右侧单圆的观感（右手拇指更易够到）。
    private func collapseTabOffset(for index: Int) -> CGFloat {
        let order = CGFloat(tabs.count - 1 - index)
        return order * AppSpacing.sm * clampedProgress
    }

    private func jellyInfluence(for index: Int, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let itemWidth = max(1, width / CGFloat(tabs.count))
        let focus = CGFloat(selectedTab.rawValue) - (dragTranslation.width / itemWidth)
        let distance = abs(CGFloat(index) - focus)
        return max(0, 1 - min(1, distance))
    }
}

private struct GlassTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let jellyInfluence: CGFloat
    let dragTranslation: CGSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.chromeIconMedium)
                    .frame(height: AppSpacing.tabBarIconRowHeight)
                Text(label)
                    .font(.label)
            }
            .foregroundStyle(isSelected ? AppColors.inkPrimary : AppColors.tabBarInactiveLabel)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.tabBarButtonRowHeight)
            .scaleEffect(
                x: 1 + (jellyInfluence * 0.12) - (abs(dragTranslation.height) / 1400),
                y: 1 + (jellyInfluence * 0.06) + (abs(dragTranslation.height) / 1700)
            )
            .offset(
                x: dragTranslation.width * 0.02 * jellyInfluence,
                y: -abs(dragTranslation.width) * 0.008 * jellyInfluence
            )
            .background {
                if isSelected || jellyInfluence > 0.02 {
                    Capsule()
                        .fill(AppColors.tabBarActiveItem.opacity(isSelected ? 1 : 0.42))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.36), lineWidth: 0.7)
                        )
                        .scaleEffect(
                            x: 1 + (jellyInfluence * 0.08),
                            y: 1 - (jellyInfluence * 0.04)
                        )
                        .offset(x: dragTranslation.width * 0.012 * jellyInfluence)
                        .if(isSelected) { view in
                            view.matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        }
                }
            }
        }
        .buttonStyle(.plain)
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
