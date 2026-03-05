//
//  OB_PersonalizeProgress.swift
//  Flamora app
//
//  Onboarding - Personalize Stage Progress Bar
//

import SwiftUI

struct OB_PersonalizeProgress: View {
    let currentStep: Int
    var totalSteps: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("STEP \(currentStep) OF \(totalSteps)")
                .font(.label)
                .foregroundColor(AppColors.textTertiary)
                .tracking(1)

            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i < currentStep ? Color.white : Color(hex: "#333333"))
                        .frame(height: 3)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
    }
}

#Preview {
    OB_PersonalizeProgress(currentStep: 3, totalSteps: 5)
        .background(AppBackgroundView())
}
