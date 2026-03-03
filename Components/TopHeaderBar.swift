//
//  TopHeaderBar.swift
//  Flamora app
//
//  顶部导航栏 - 页面标题风格
//

import SwiftUI

struct TopHeaderBar: View {
    let pageTitle: String
    let leftAction: HeaderLeftAction
    let onSettingsTapped: () -> Void
    let isVisible: Bool
    static let height: CGFloat = 60

    var body: some View {
        HStack(spacing: 10) {
            // Left: dot-grid icon + page title
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppColors.textTertiary)

                Text(pageTitle.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(0.6)
            }

            Spacer()

            // Right: contextual action + settings
            HStack(spacing: 10) {
                switch leftAction {
                case .none:
                    EmptyView()
                case .eye(let action):
                    HeaderIconButton(icon: "eye", action: action)
                case .flameToggle(let isOn, let action):
                    FlameTogglePill(isOn: isOn, action: action)
                }

                HeaderIconButton(icon: "gearshape", action: onSettingsTapped)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .frame(height: isVisible ? nil : 0)
        .clipped()
    }
}

enum HeaderLeftAction {
    case none
    case eye(action: () -> Void)
    case flameToggle(isOn: Bool, action: () -> Void)
}

private struct HeaderIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(AppColors.surface)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle()
                        .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            TopHeaderBar(
                pageTitle: "Home",
                leftAction: .flameToggle(isOn: true, action: {}),
                onSettingsTapped: {},
                isVisible: true
            )
            Spacer()
        }
    }
}
