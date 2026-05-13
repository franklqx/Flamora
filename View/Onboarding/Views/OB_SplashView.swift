//
//  OB_SplashView.swift
//  Meridian
//
//  Onboarding - Step 0: Animated Splash
//

import SwiftUI

struct OB_SplashView: View {
    let onNext: () -> Void

    @State private var letterOpacities: [Double] = Array(repeating: 0, count: 8)

    private let letters = ["M", "E", "R", "I", "D", "I", "A", "N"]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fontSize = min(34, max(20, width * 0.07))
            let letterScale = fontSize / AppTypography.h1
            let letterSpacing = min(10, max(3, width * 0.022))

            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                HStack(spacing: letterSpacing) {
                    ForEach(0..<letters.count, id: \.self) { index in
                        Text(letters[index])
                            .font(.h1)
                            .fontWeight(.light)
                            .scaleEffect(letterScale)
                            .foregroundColor(AppColors.textPrimary)
                            .opacity(letterOpacities[index])
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            for index in 0..<letters.count {
                withAnimation(.easeIn(duration: 0.4).delay(Double(index) * 0.12)) {
                    letterOpacities[index] = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onNext()
            }
        }
    }
}

#Preview {
    OB_SplashView(onNext: {})
        .background(AppBackgroundView())
}
