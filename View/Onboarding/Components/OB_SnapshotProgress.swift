//
//  OB_SnapshotProgress.swift
//  Flamora app
//
//  Onboarding - Financial Snapshot Progress Indicator
//

import SwiftUI

struct OB_SnapshotProgress: View {
    let current: Int
    var total: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Financial Snapshot \(current)/\(total)")
                .font(.label)
                .foregroundStyle(.white)
                .tracking(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)

            GeometryReader { geo in
                let barWidth = geo.size.width
                let segmentWidth = barWidth / CGFloat(total)
                let fillWidth = segmentWidth * CGFloat(current)

                ZStack(alignment: .leading) {
                    // 背景轨道
                    Capsule()
                        .fill(AppColors.surfaceInput)
                        .frame(height: 4)

                    // 渐变进度
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, fillWidth), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    OB_SnapshotProgress(current: 2)
        .background(AppBackgroundView())
}
