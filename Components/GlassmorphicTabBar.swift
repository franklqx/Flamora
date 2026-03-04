//
//  GlassmorphicTabBar.swift
//  Flamora app
//
//  底部 Tab Bar - 超透明玻璃质感，小方框图标按钮
//

import SwiftUI

struct GlassmorphicTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house",
                isSelected: selectedTab == 0
            ) { selectedTab = 0 }

            Spacer()

            TabBarButton(
                icon: "creditcard",
                isSelected: selectedTab == 1
            ) { selectedTab = 1 }

            Spacer()

            TabBarButton(
                icon: "chart.pie",
                isSelected: selectedTab == 2
            ) { selectedTab = 2 }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(AppColors.glassBackground)
                RoundedRectangle(cornerRadius: 28)
                    .stroke(AppColors.glassBorder, lineWidth: 0.75)
            }
        )
        .shadow(color: Color.black.opacity(0.50), radius: 20, x: 0, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 6)
    }
}

struct TabBarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // 小方框背景
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                        ? Color.white.opacity(0.12)
                        : Color.clear
                    )
                    .frame(width: 46, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected
                                    ? Color.white.opacity(0.18)
                                    : Color.clear,
                                lineWidth: 0.75
                            )
                    )

                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.35))
            }
            .frame(width: 46, height: 40)
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
