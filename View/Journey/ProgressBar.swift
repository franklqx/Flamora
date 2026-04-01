//
//  ProgressBar.swift
//  Flamora app
//
//  通用进度条组件
//

import SwiftUI

struct ProgressBar: View {
    let progress: Double    // 0.0 – 1.0
    let color: Color
    var height: CGFloat = 8

    init(progress: Double, color: Color, height: CGFloat = 8) {
        self.progress = progress
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let safeWidth = width.isFinite && width >= 0 ? width : 0
            let clampedProgress = max(0, min(progress, 1.0))
            let progressWidth = max(0, safeWidth * clampedProgress)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.full)
                    .fill(AppColors.progressTrack)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: AppRadius.full)
                    .fill(color)
                    .frame(width: progressWidth, height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ProgressBar(progress: 0.51, color: AppColors.progressOrange)
        ProgressBar(progress: 0.42, color: AppColors.progressBlue)
        ProgressBar(progress: 0.25, color: AppColors.progressPurple)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}
