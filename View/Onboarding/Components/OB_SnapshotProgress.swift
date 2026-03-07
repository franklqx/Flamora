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
                .foregroundColor(.white)
                .tracking(0.8)

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(
                            i < current
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [AppColors.accentBlue, AppColors.accentPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                : AnyShapeStyle(AppColors.surfaceInput)
                        )
                        .frame(height: 3)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: current)
        }
    }
}

#Preview {
    OB_SnapshotProgress(current: 2)
        .background(AppBackgroundView())
}
