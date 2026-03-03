//
//  OBV2_SplashView.swift
//  Flamora app
//
//  V2 Onboarding - Step 0: Animated Splash
//

import SwiftUI

struct OBV2_SplashView: View {
    let onNext: () -> Void

    @State private var textOpacity: Double = 0
    @State private var dotPulse = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("F L A M O R A")
                    .font(.system(size: 28, weight: .light))
                    .tracking(8)
                    .foregroundColor(AppColors.textPrimary)
                    .opacity(textOpacity)

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(AppColors.textPrimary)
                            .frame(width: 6, height: 6)
                            .opacity(dotPulse ? 1 : 0.3)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: dotPulse
                            )
                    }
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                textOpacity = 1
            }
            dotPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                onNext()
            }
        }
    }
}
