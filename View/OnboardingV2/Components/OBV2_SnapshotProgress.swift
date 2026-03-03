//
//  OBV2_SnapshotProgress.swift
//  Flamora app
//
//  V2 Onboarding - Financial Snapshot Progress Indicator
//

import SwiftUI

struct OBV2_SnapshotProgress: View {
    let current: Int
    var total: Int = 5

    var body: some View {
        HStack {
            Text("FINANCIAL SNAPSHOT")
                .font(.label)
                .foregroundColor(.white)
                .tracking(1)

            Spacer()

            Text("\(current)/\(total)")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }
}
