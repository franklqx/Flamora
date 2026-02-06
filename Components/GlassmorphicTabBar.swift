//
//  GlassmorphicTabBar.swift
//  Flamora app
//
//  iOS 18 风格透明玻璃 Tab Bar - 根据背景颜色变化
//

import SwiftUI

struct GlassmorphicTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house.fill",
                label: "Home",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }

            Spacer()

            TabBarButton(
                icon: "chart.bar.fill",
                label: "Savings",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }

            Spacer()

            TabBarButton(
                icon: "chart.line.uptrend.xyaxis",
                label: "Investment",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
        }
        .padding(.horizontal, 32)
        .frame(height: 64)
        .background(
            ZStack {
                // 透明玻璃背景 - 会根据下面的内容变化
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // 细微的白色边框
                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                }

                Image(systemName: icon)
                    .font(.system(size: isSelected ? 22 : 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            }
            .frame(width: 50, height: 50)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            GlassmorphicTabBar(selectedTab: .constant(0))
        }
    }
}
