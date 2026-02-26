//
//  JourneyContainerView.swift
//  Flamora app
//
//  Journey 和 Simulator 的容器视图 - 支持滑动切换
//

import SwiftUI

struct JourneyContainerView: View {
    @Binding var isSimulatorShown: Bool
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var isFlipping = false

    private var bottomPadding: CGFloat { isSimulatorShown ? 0 : AppSpacing.tabBarReserve }

    var body: some View {
        ZStack {
            Color.clear

            if plaidManager.hasLinkedBank {
                // 已连接：显示 Journey + Simulator（带 3D 翻转）
                ZStack {
                    JourneyView(bottomPadding: bottomPadding, onFireTapped: {
                        flip(to: true)
                    })
                    .rotation3DEffect(
                        .degrees(isSimulatorShown ? -70 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .opacity(!isSimulatorShown ? 1 : 0)
                    .allowsHitTesting(!isSimulatorShown && !isFlipping)

                    SimulatorView(
                        bottomPadding: bottomPadding,
                        isFireOn: true,
                        onFireToggle: { flip(to: false) }
                    )
                    .rotation3DEffect(
                        .degrees(isSimulatorShown ? 0 : 70),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .opacity(isSimulatorShown ? 1 : 0)
                    .allowsHitTesting(isSimulatorShown && !isFlipping)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            guard abs(horizontal) > abs(vertical) else { return }
                            if horizontal < -100 && !isSimulatorShown { flip(to: true) }
                            else if horizontal > 100 && isSimulatorShown { flip(to: false) }
                        }
                )
            } else {
                // 未连接：显示 CTA 初始状态
                JourneyCTAView(bottomPadding: bottomPadding)
            }
        }
    }

    private func flip(to simulator: Bool) {
        guard !isFlipping else { return }
        isFlipping = true
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isSimulatorShown = simulator
        }
        // 动画结束后重新启用 hit-testing（spring 0.6/0.8 约 0.9s 完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isFlipping = false
        }
    }
}

// MARK: - Journey 初始状态 CTA

private struct JourneyCTAView: View {
    let bottomPadding: CGFloat
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xl)

                    // Hero icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "#A78BFA").opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#A78BFA"), Color(hex: "#EC4899")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text("Build Your\nFIRE Plan")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Connect your accounts to see your real\nFIRE progress and net worth.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    // Feature chips
                    VStack(spacing: 12) {
                        ForEach(features, id: \.0) { icon, text in
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "#A78BFA"), Color(hex: "#EC4899")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 24)

                                Text(text)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#121212"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "#222222"), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)

                    Spacer(minLength: AppSpacing.xl)

                    // CTA Button
                    Button(action: {
                        Task {
                            if !subscriptionManager.isPremium {
                                await subscriptionManager.checkStatus()
                            }
                            if subscriptionManager.isPremium {
                                await plaidManager.startLinkFlow()
                            } else {
                                subscriptionManager.showPaywall = true
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if plaidManager.isConnecting {
                                ProgressView().tint(.black)
                            } else {
                                Text("Build My Plan")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(plaidManager.isConnecting)
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.bottom, 120)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.bottom, bottomPadding)
                .padding(.top, AppSpacing.lg)
            }
        }
    }

    private let features: [(String, String)] = [
        ("chart.line.uptrend.xyaxis", "Real-time FIRE progress tracking"),
        ("banknote", "Live net worth from all accounts"),
        ("calendar", "Monthly savings & budget trends"),
        ("sparkles", "AI-powered FIRE insights")
    ]
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
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
