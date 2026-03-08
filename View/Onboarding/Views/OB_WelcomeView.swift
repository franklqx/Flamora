//
//  OB_WelcomeView.swift
//  Flamora app
//
//  Onboarding - Step 1: Welcome Carousel (4 pages)
//  • 背景：程序化蓝天白云（不依赖图片资产）
//  • 翻页：点击左半屏 ← 上一张 / 点击右半屏 → 下一张
//

import SwiftUI

// MARK: - Main Welcome View

struct OB_WelcomeView: View {
    let onNext: () -> Void

    @State private var currentSlide = 0

    private let slides: [WelcomeSlide] = [
        WelcomeSlide(title: "Real numbers.\nReal progress.\nReal freedom.", cardType: .fireProgress),
        WelcomeSlide(title: "Know exactly where\nevery dollar goes.", cardType: .budget),
        WelcomeSlide(title: "Build the habit that\ngets you there.", cardType: .savings),
        WelcomeSlide(title: "Watch your money\nwork for you", cardType: .netWorth),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Sky background ──────────────────────────────────────
            ProceduralSkyView()
                .ignoresSafeArea()

            // Subtle bottom vignette for CTA legibility
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.22)],
                startPoint: UnitPoint(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Main content column ─────────────────────────────────
            VStack(spacing: 0) {

                // Top icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(Color.white.opacity(0.42), lineWidth: 1)
                        )
                        .frame(width: 42, height: 42)
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.88))
                }
                .padding(.top, 22)

                // Slide headline — serif font for editorial feel
                Text(slides[currentSlide].title)
                    .font(.obSlideTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .padding(.top, 26)
                    .frame(minHeight: 136, alignment: .top)
                    .animation(.easeInOut(duration: 0.25), value: currentSlide)

                Spacer().frame(height: 10)

                // Slide card — wrapped in animation context
                Group {
                    switch slides[currentSlide].cardType {
                    case .fireProgress: WelcomeFireProgressCard()
                    case .budget:       WelcomeBudgetCard()
                    case .savings:     WelcomeSavingsCard()
                    case .netWorth:    WelcomeNetWorthCard()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: currentSlide > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal:   .move(edge: currentSlide > 0 ? .leading  : .trailing).combined(with: .opacity)
                ))
                .id(currentSlide)
                .padding(.horizontal, 20)

                Spacer(minLength: 18)

                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentSlide ? Color.white : Color.white.opacity(0.36))
                            .frame(width: i == currentSlide ? 20 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: currentSlide)
                    }
                }
                .padding(.bottom, 20)

                // Get Started CTA
                OB_PrimaryButton(title: "Get Started", action: onNext)
            }

            // ── Left / right tap overlay (do not cover CTA) ─────────
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentSlide = (currentSlide - 1 + slides.count) % slides.count
                            }
                        }
                        .frame(width: geo.size.width / 2)

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentSlide = (currentSlide + 1) % slides.count
                            }
                        }
                        .frame(width: geo.size.width / 2)
                }
            }
            .padding(.bottom, 56 + 48 + 26 + 38)  // 56 按钮高度 + xxl 底部 + 其他
        }
    }
}

// MARK: - Slide Model

private struct WelcomeSlide {
    enum CardType { case fireProgress, budget, savings, netWorth }
    let title: String
    let cardType: CardType
}

// MARK: - Procedural Sky Background

struct ProceduralSkyView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.26, green: 0.48, blue: 0.76),
                    Color(red: 0.34, green: 0.57, blue: 0.82),
                    Color(red: 0.46, green: 0.68, blue: 0.88),
                    Color(red: 0.63, green: 0.80, blue: 0.93),
                    Color(red: 0.82, green: 0.92, blue: 0.97),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Ellipse()
                .fill(Color.white.opacity(0.52))
                .frame(width: 310, height: 105)
                .blur(radius: 40)
                .offset(x: 75, y: -250)

            Ellipse()
                .fill(Color.white.opacity(0.44))
                .frame(width: 240, height: 78)
                .blur(radius: 32)
                .offset(x: -68, y: -175)

            Ellipse()
                .fill(Color.white.opacity(0.58))
                .frame(width: 390, height: 130)
                .blur(radius: 56)
                .offset(x: 12, y: 85)

            Ellipse()
                .fill(Color.white.opacity(0.46))
                .frame(width: 225, height: 72)
                .blur(radius: 28)
                .offset(x: 108, y: 28)

            Ellipse()
                .fill(Color.white.opacity(0.40))
                .frame(width: 275, height: 88)
                .blur(radius: 46)
                .offset(x: 58, y: 215)

            Ellipse()
                .fill(Color.white.opacity(0.34))
                .frame(width: 195, height: 62)
                .blur(radius: 38)
                .offset(x: -88, y: 265)

            RadialGradient(
                colors: [Color.white.opacity(0.16), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 320
            )
        }
    }
}

// MARK: - Glass Card Base

private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.36), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 6)
    }
}

// MARK: - Card 1: FIRE Progress

private struct WelcomeFireProgressCard: View {
    @State private var trimEnd: CGFloat = 0

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("FIRE PROGRESS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.70))
                        .tracking(1.2)
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(7)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }

                Spacer().frame(height: 14)

                Text("On track to retire at your target age")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 36)

                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 9)
                            .frame(width: 118, height: 118)
                        Circle()
                            .trim(from: 0, to: trimEnd)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .frame(width: 118, height: 118)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("13%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                            Text("ACHIEVED")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white.opacity(0.58))
                                .tracking(0.6)
                        }
                    }
                    Spacer()
                }

                Spacer().frame(height: 10)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) { trimEnd = 0.13 }
        }
    }
}

// MARK: - Card 2: Budget

private struct WelcomeBudgetCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("AUTO-CATEGORIZED · THIS MONTH")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(0.3)
                }
                .padding(.bottom, 12)

                budgetSection(
                    name: "NEEDS", amount: "$2,678", pct: "62% OF INCOME", progress: 0.62,
                    items: [("Rent","$1,768","41%"), ("Groceries","$614","14%"), ("Utilities","$296","7%")]
                )

                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.vertical, 10)

                budgetSection(
                    name: "WANTS", amount: "$955", pct: "38% OF INCOME", progress: 0.38,
                    items: [("Dining","$420","10%"), ("Shopping","$325","8%"), ("Travel","$210","5%")]
                )
            }
        }
    }

    @ViewBuilder
    private func budgetSection(name: String, amount: String, pct: String, progress: CGFloat,
                               items: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(0.5)
                Spacer()
                Text(amount)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            GeometryReader { g in
                Capsule()
                    .fill(Color.white)
                    .frame(width: g.size.width * progress, height: 2)
            }
            .frame(height: 2)

            Text(pct)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.48))
                .padding(.bottom, 4)

                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 4) {
                                    Text(item.0)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.white.opacity(0.82))
                                    Spacer()
                                    Text(item.1)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(item.2)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 1.5)
            }
        }
    }
}

// MARK: - Card 3: Savings Overview

private struct WelcomeSavingsCard: View {
    private let months = ["J","F","M","A","M","J","J","A","S","O","N","D"]
    private let values: [CGFloat] = [0.55, 0.65, 0.50, 0.70, 0.75, 0.60, 0.80, 0.90, 0.72, 0, 0, 0]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SAVING OVERVIEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.50))
                        .padding(5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("US$20,200")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Total saved this year")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                }

                GeometryReader { geo in
                    let n = months.count
                    let gap: CGFloat = 3
                    let barW = (geo.size.width - gap * CGFloat(n - 1)) / CGFloat(n)
                    let maxH = geo.size.height - 14

                    ZStack(alignment: .top) {
                        HStack(spacing: 2) {
                            ForEach(0..<18, id: \.self) { _ in
                                Capsule()
                                    .fill(Color.white.opacity(0.32))
                                    .frame(width: 4, height: 1)
                            }
                            Text("TARGET")
                                .font(.system(size: 6, weight: .semibold))
                                .foregroundColor(.white.opacity(0.38))
                                .tracking(0.3)
                        }
                        .offset(y: maxH * 0.17)

                        HStack(alignment: .bottom, spacing: gap) {
                            ForEach(Array(zip(months, values).enumerated()), id: \.offset) { _, pair in
                                let month = pair.0
                                let val = pair.1
                                VStack(spacing: 3) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(val > 0 ? Color.white : Color.white.opacity(0.18))
                                        .frame(width: barW, height: max(6, maxH * (val > 0 ? val : 0.28)))
                                    Text(month)
                                        .font(.system(size: 6))
                                        .foregroundColor(.white.opacity(0.40))
                                        .frame(width: barW)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .frame(height: 74)

                HStack {
                    statItem(label: "TARGET RATE",   value: "20%",       trailing: false)
                    Divider().background(Color.white.opacity(0.18)).frame(height: 28)
                    statItem(label: "TARGET SAVING", value: "US$2,000",  trailing: true)
                }
            }
        }
    }

    @ViewBuilder
    private func statItem(label: String, value: String, trailing: Bool) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .tracking(0.4)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
    }
}

// MARK: - Card 4: Net Worth

private struct WelcomeNetWorthCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL NET WORTH")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                            .tracking(0.8)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("$210,150")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                            Text("+13.8%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.accentGreen)
                        }
                    }
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(8)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let pts: [CGPoint] = [
                        (0.00,0.50),(0.10,0.60),(0.18,0.42),(0.26,0.62),(0.34,0.38),
                        (0.42,0.55),(0.50,0.35),(0.58,0.50),(0.66,0.30),(0.74,0.42),
                        (0.82,0.25),(0.90,0.38),(1.00,0.20)
                    ].map { CGPoint(x: $0.0 * w, y: $0.1 * h) }

                    Path { p in
                        p.move(to: pts[0])
                        for i in 0..<pts.count - 1 {
                            let cp1 = CGPoint(x: (pts[i].x + pts[i+1].x) / 2, y: pts[i].y)
                            let cp2 = CGPoint(x: (pts[i].x + pts[i+1].x) / 2, y: pts[i+1].y)
                            p.addCurve(to: pts[i+1], control1: cp1, control2: cp2)
                        }
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                .frame(height: 58)

                HStack(spacing: 0) {
                    ForEach(["1W","1M","3M","YTD","ALL"], id: \.self) { period in
                        let selected = period == "1M"
                        Text(period)
                            .font(.system(size: 10, weight: selected ? .semibold : .regular))
                            .foregroundColor(selected ? .black : .white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selected ? Color.white : Color.clear)
                            .clipShape(Capsule())
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    OB_WelcomeView(onNext: {})
        .background(AppBackgroundView())
}
