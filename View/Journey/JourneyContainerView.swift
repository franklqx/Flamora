//
//  JourneyContainerView.swift
//  Flamora app
//
//  Journey 和 Simulator 的容器视图 - 支持滑动切换
//

import SwiftUI

struct JourneyContainerView: View {
    @Binding var isSimulatorShown: Bool
    private var bottomPadding: CGFloat { isSimulatorShown ? 0 : AppSpacing.tabBarReserve }

    var body: some View {
        ZStack {
            Color.clear

            ZStack {
                // Journey 页面 (正面)
                JourneyView(bottomPadding: bottomPadding, onFireTapped: {
                    flip(to: true)
                })
                .rotation3DEffect(
                    .degrees(isSimulatorShown ? -90 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(!isSimulatorShown ? 1 : 0)
                .allowsHitTesting(!isSimulatorShown)

                // Simulator 页面 (背面)
                SimulatorView(
                    bottomPadding: bottomPadding,
                    isFireOn: true,
                    onFireToggle: {
                        flip(to: false)
                    }
                )
                .rotation3DEffect(
                    .degrees(isSimulatorShown ? 0 : 90),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(isSimulatorShown ? 1 : 0)
                .allowsHitTesting(isSimulatorShown)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard abs(horizontal) > abs(vertical) else { return }

                    // 左滑: 进入 Simulator
                    if horizontal < -100 && !isSimulatorShown {
                        flip(to: true)
                    }
                    // 右滑: 返回 Journey
                    else if horizontal > 100 && isSimulatorShown {
                        flip(to: false)
                    }
                }
        )
    }

    private func flip(to simulator: Bool) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isSimulatorShown = simulator
        }
    }
}

// MARK: - Analysis Card
struct AnalysisCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#A78BFA"), Color(hex: "#F9A8D4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(18)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    JourneyContainerView(isSimulatorShown: .constant(false))
}
