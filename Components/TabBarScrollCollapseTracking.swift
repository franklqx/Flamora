//
//  TabBarScrollCollapseTracking.swift
//  Flamora app
//
//  对齐 iOS 26 TabView「下滑收起 Tab Bar」体验：用 ScrollGeometry 将垂直偏移映射为 0...1，
//  与 MainTabView 里 Sheet 高度驱动的收起取 max 合并（见 `tabBarCollapseProgress`）。
//

import SwiftUI

extension View {
    /// 将主 ScrollView 的垂直滚动映射为底部自定义 Tab 条的收起进度（0 = 顶栏展开，1 ≈ 下滑足够距离后完全收起）。
    func tracksTabBarScrollCollapse(_ binding: Binding<CGFloat>) -> some View {
        modifier(TabBarScrollCollapseModifier(progress: binding))
    }
}

private struct TabBarScrollCollapseModifier: ViewModifier {
    @Binding var progress: CGFloat

    /// 与系统 Tab 条「开始下滑即让位」相近的手感（pt）。
    private let collapseThreshold: CGFloat = 88

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, geo.contentOffset.y)
            } action: { _, newY in
                let p = min(1, newY / collapseThreshold)
                if abs(progress - p) > 0.015 {
                    progress = p
                }
            }
        } else {
            content
        }
    }
}
