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
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .trailing)

            GeometryReader { geo in
                let segmentWidth = geo.size.width / CGFloat(totalSteps)
                let fillWidth = segmentWidth * CGFloat(currentStep)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.surfaceInput)
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, fillWidth), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    OB_PersonalizeProgress(currentStep: 3, totalSteps: 5)
        .background(AppBackgroundView())
}
