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
    let isSimulatorShown: Bool
    let onFlameToggle: () -> Void
    @Namespace private var tabIndicator

    private let tabs: [(icon: String, label: String)] = [
        ("house", "Home"),
        ("creditcard", "Cash"),
        ("chart.pie", "Invest")
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左侧玻璃胶囊 — Simulator 激活时滑出消失
            if !isSimulatorShown {
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
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Spacer()

            // 右侧火焰 FAB — 始终可见，62×62，激活时渐变色
            Button(action: onFlameToggle) {
                Image("FlameIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(
                        isSimulatorShown
                            ? AnyShapeStyle(LinearGradient(
                                colors: [AppColors.accentPurple, AppColors.accentPink],
                                startPoint: .top,
                                endPoint: .bottom))
                            : AnyShapeStyle(AppColors.overlayWhiteForegroundMuted)
                    )
                    .frame(width: 20, height: 20)
                    .frame(width: 62, height: 62)
            }
            .buttonStyle(.plain)
            .tint(isSimulatorShown ? AppColors.gradientFlamePill[1] : AppColors.overlayWhiteForegroundMuted)
            .glassEffect(.regular, in: .circle)
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSimulatorShown)
        .padding(.horizontal, 21)
        .padding(.bottom, 0)
        .padding(.top, 2)
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
                selectedTab: .constant(0),
                isSimulatorShown: false,
                onFlameToggle: {}
            )
        }
    }
}
