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
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textTertiary)

                Text(pageTitle.uppercased())
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(0.6)
            }

            Spacer()

            HStack(spacing: 10) {
                switch leftAction {
                case .none:
                    EmptyView()
                case .eye(let action):
                    HeaderIconButton(icon: "eye", action: action)
                case .close(let action):
                    HeaderIconButton(icon: "xmark", action: action)
                case .flame(let isActive, let action):
                    FlameCapsuleButton(isActive: isActive, action: action)
                }

                HeaderIconButton(icon: "gearshape", action: onSettingsTapped)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppColors.backgroundPrimary.ignoresSafeArea(edges: .top))
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .frame(height: isVisible ? nil : 0)
    }
}

enum HeaderLeftAction {
    case none
    case eye(action: () -> Void)
    case close(action: () -> Void)
    case flame(isActive: Bool, action: () -> Void)
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
                        .font(.figureSecondarySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                )
                .overlay(
                    Circle()
                        .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FlameCapsuleButton: View {
    let isActive: Bool
    let action: () -> Void

    private let trackWidth: CGFloat = 56
    private let trackHeight: CGFloat = 26
    private let circleSize: CGFloat = 38

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isActive ? .trailing : .leading) {
                // 轨道（窄胶囊）
                Capsule()
                    .fill(AppColors.surface)
                    .frame(width: trackWidth, height: trackHeight)
                    .overlay(Capsule().stroke(AppColors.surfaceBorder, lineWidth: 0.75))

                // 圆圈（比轨道大，溢出上下）
                Circle()
                    .fill(AppColors.surface)
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Image("FlameIcon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(
                                isActive
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [AppColors.accentPurple, AppColors.accentPink],
                                        startPoint: .top,
                                        endPoint: .bottom))
                                    : AnyShapeStyle(AppColors.textPrimary)
                            )
                            .frame(width: 16, height: 16)
                    )
                    .overlay(Circle().stroke(AppColors.surfaceBorder, lineWidth: 0.75))
                    .shadow(color: AppColors.cardShadow, radius: 4, y: 2)
                    .offset(x: isActive ? 2 : -2)
            }
            .frame(width: trackWidth, height: circleSize)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack {
            TopHeaderBar(
                pageTitle: "Home",
                leftAction: .none,
                onSettingsTapped: {},
                isVisible: true
            )
            Spacer()
        }
    }
}
