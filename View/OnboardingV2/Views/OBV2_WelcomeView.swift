//
//  OBV2_WelcomeView.swift
//  Flamora app
//
//  V2 Onboarding - Step 1: Welcome Carousel (4 pages)
//

import SwiftUI

struct OBV2_WelcomeView: View {
    let onNext: () -> Void

    @State private var selectedTab = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            WelcomeSkyBackground()

            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    WelcomePageFire().tag(0)
                    WelcomePageSpending(isActive: selectedTab == 1).tag(1)
                    WelcomePageSavings().tag(2)
                    WelcomePageNetWorth().tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedTab) { _, _ in resetTimer() }

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 7, height: 7)
                            .opacity(i == selectedTab ? 1 : 0.3)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            OBV2_PrimaryButton(title: "Get Started", action: onNext)
                .padding(.bottom, 12)
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = (selectedTab + 1) % 4
            }
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        startTimer()
    }
}

// MARK: - Sky Background

private struct WelcomeSkyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#1F4F92"),
                    Color(hex: "#3A7BD5"),
                    Color(hex: "#5A9ADE"),
                    Color(hex: "#8BB9E8"),
                    Color(hex: "#C5E0F5"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Ellipse()
                .fill(Color.white.opacity(0.15))
                .frame(width: 620, height: 140)
                .blur(radius: 45)
                .offset(y: -120)

            Ellipse()
                .fill(Color.white.opacity(0.2))
                .frame(width: 540, height: 170)
                .blur(radius: 55)
                .offset(y: 80)

            Ellipse()
                .fill(Color.white.opacity(0.3))
                .frame(width: 760, height: 220)
                .blur(radius: 65)
                .offset(y: 260)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Card (frosted material)

private struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
    }
}

extension View {
    fileprivate func glassCard() -> some View {
        modifier(GlassCard())
    }
}

// MARK: - Page Layout

private struct WelcomePageLayout<Card: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let card: () -> Card

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)

            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white.opacity(0.15)))
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                .padding(.bottom, 20)

            Text(title)
                .font(.system(size: AppTypography.h1, weight: .light, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // Card — max ~280pt, 32pt side margins
            card()
                .frame(maxHeight: 280)
                .padding(.horizontal, 32)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)

            Spacer()
        }
    }
}

// MARK: - Page 1: FIRE Progress

private struct WelcomePageFire: View {
    var body: some View {
        WelcomePageLayout(icon: "circle.grid.3x3.fill", title: "Real numbers.\nReal progress.\nReal freedom.") {
            VStack(spacing: 14) {
                HStack {
                    Text("FIRE PROGRESS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1)
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text("On track to retire at your target age")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)

                FireGauge()
            }
            .glassCard()
        }
    }
}

private struct FireGauge: View {
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0.5, to: 0.565)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("13")
                        .font(.system(size: 32, weight: .bold))
                    Text("%")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))

                Text("ACHIEVED")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)
            }
            .offset(y: -8)
        }
        .frame(height: 72)
        .padding(.top, 4)
    }
}

// MARK: - Page 2: Spending

private struct WelcomePageSpending: View {
    let isActive: Bool
    @State private var showItems = false

    var body: some View {
        WelcomePageLayout(icon: "circle.grid.3x3.fill", title: "Know exactly where\nevery dollar goes.") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("AUTO-CATEGORIZED \u{00B7} THIS MONTH")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                }

                SpendingSection(
                    title: "NEEDS", total: "$2,678", pct: "62%",
                    items: [("Rent", "$1,768", "41%"), ("Groceries", "$614", "14%"), ("Utilities", "$296", "7%")],
                    showItems: showItems, startIndex: 0
                )

                Divider().overlay(Color.white.opacity(0.15))

                SpendingSection(
                    title: "WANTS", total: "$955", pct: "38%",
                    items: [("Dining", "$420", "10%"), ("Shopping", "$325", "8%"), ("Travel", "$210", "5%")],
                    showItems: showItems, startIndex: 3
                )
            }
            .glassCard()
        }
        .onChange(of: isActive) { _, active in
            if active {
                showItems = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showItems = true }
            }
        }
        .onAppear {
            if isActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showItems = true }
            }
        }
    }
}

private struct SpendingSection: View {
    let title: String
    let total: String
    let pct: String
    let items: [(String, String, String)]
    let showItems: Bool
    let startIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(total)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            GeometryReader { geo in
                let fraction = (Double(pct.replacingOccurrences(of: "%", with: "")) ?? 0) / 100
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: geo.size.width * fraction, height: 3)
            }
            .frame(height: 3)

            Text("\(pct) OF INCOME")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .trailing)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(item.1)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text(item.2)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(4)
                }
                .opacity(showItems ? 1 : 0)
                .offset(y: showItems ? 0 : 10)
                .animation(.easeOut(duration: 0.3).delay(Double(startIndex + index) * 0.08), value: showItems)
            }
        }
    }
}

// MARK: - Page 3: Savings

private struct WelcomePageSavings: View {
    private let barData: [CGFloat] = [0.4, 0.55, 0.5, 0.65, 0.7, 0.6, 0.75, 0.8, 0.7, 0.85, 0.9, 0.78]
    private let months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    var body: some View {
        WelcomePageLayout(icon: "circle.grid.3x3.fill", title: "Build the habit that\ngets you there.") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SAVING OVERVIEW")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("US$20,200")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Total saved this year")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }

                SavingsBarChart(barData: barData, months: months)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TARGET RATE")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Text("20%")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TARGET SAVING")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Text("US$2,000")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .glassCard()
        }
    }
}

private struct SavingsBarChart: View {
    let barData: [CGFloat]
    let months: [String]

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<12, id: \.self) { i in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(i < 9 ? 0.9 : 0.25))
                            .frame(height: 55 * barData[i])

                        Text(months[i])
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Text("TARGET")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(height: 1)
            }
            .offset(y: 8)
        }
        .frame(height: 75)
    }
}

// MARK: - Page 4: Net Worth

private struct WelcomePageNetWorth: View {
    private let tabs = ["1W", "1M", "3M", "YTD", "ALL"]

    var body: some View {
        WelcomePageLayout(icon: "circle.grid.3x3.fill", title: "Watch your money\nwork for you") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("TOTAL NET WORTH")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    Spacer()
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("$210,150")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("+13.8%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#22C55E").opacity(0.95))
                }

                WelcomeWaveChart()
                    .frame(height: 70)

                NetWorthTabs(tabs: tabs)
            }
            .glassCard()
        }
    }
}

private struct NetWorthTabs: View {
    let tabs: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let selected = tab == "1M"
                Text(tab)
                    .font(.system(size: 11, weight: selected ? .bold : .regular))
                    .foregroundColor(.white.opacity(selected ? 1 : 0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.white.opacity(selected ? 0.22 : 0))
                    )
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Wave Chart

private struct WelcomeWaveChart: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pts: [CGFloat] = [0.6, 0.55, 0.65, 0.5, 0.56, 0.7, 0.62, 0.76, 0.66, 0.8, 0.76, 0.86]

            WaveChartPath(points: pts, w: w, h: h)
                .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
}

private struct WaveChartPath: Shape {
    let points: [CGFloat]
    let w: CGFloat
    let h: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = w / CGFloat(points.count - 1)
        let mapped = points.enumerated().map { (i, val) in
            CGPoint(x: CGFloat(i) * step, y: h * (1.0 - val))
        }
        guard let first = mapped.first else { return path }
        path.move(to: first)
        for i in 1..<mapped.count {
            let prev = mapped[i - 1]
            let curr = mapped[i]
            let midX = (prev.x + curr.x) / 2
            path.addCurve(
                to: curr,
                control1: CGPoint(x: midX, y: prev.y),
                control2: CGPoint(x: midX, y: curr.y)
            )
        }
        return path
    }
}
