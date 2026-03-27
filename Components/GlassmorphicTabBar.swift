//
//  GlassmorphicTabBar.swift
//  Flamora app
//
//  底部 Tab Bar - iOS 26 原生液态玻璃质感 (FabBar 尺寸)
//  左侧胶囊：3个导航Tab（图标+标签）；右侧FAB圆圈：火焰按钮
//  Simulator 激活时左侧胶囊滑出消失，只剩火焰 FAB
//

import SwiftUI

struct GlassmorphicTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabIndicator

    private let tabs: [(icon: String, label: String)] = [
        ("house", "Home"),
        ("creditcard", "Cash"),
        ("chart.pie", "Invest")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                GlassTabButton(
                    icon: tabs[i].icon,
                    label: tabs[i].label,
                    isSelected: selectedTab == i,
                    namespace: tabIndicator
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = i
                    }
                }
            }
        }
        .padding(2)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 21)
        .padding(.bottom, 0)
        .padding(.top, 2)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

private struct GlassTabButton: View {
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
            .foregroundStyle(isSelected ? .white : AppColors.overlayWhiteForegroundMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppColors.glassPillStroke)
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            GlassmorphicTabBar(
                selectedTab: .constant(0)
            )
        }
    }
}
