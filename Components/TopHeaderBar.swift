//
//  TopHeaderBar.swift
//  Flamora app
//

import SwiftUI

struct TopHeaderBar: View {
    let userName: String
    let leftAction: HeaderLeftAction
    let onSettingsTapped: () -> Void
    let isVisible: Bool
    static let height: CGFloat = 72

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back,")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#7C7C7C"))

                Text(userName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            HStack(spacing: 10) {
                switch leftAction {
                case .none:
                    EmptyView()
                case .eye(let action):
                    HeaderIconButton(icon: "eye", action: action)
                case .flameToggle(let isOn, let action):
                    FlameTogglePill(isOn: isOn, action: action)
                }

                HeaderIconButton(icon: "gearshape.fill", action: onSettingsTapped)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea(edges: .top))
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
                .fill(Color(hex: "#121212"))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#222222"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TopHeaderBar(
            userName: "Enxi Lin",
            leftAction: .flameToggle(isOn: true, action: {}),
            onSettingsTapped: {},
            isVisible: true
        )
    }
}
