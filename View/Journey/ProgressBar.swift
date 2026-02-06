//
//  ProgressBar.swift
//  Flamora app
//
//  通用进度条组件
//

import SwiftUI

struct ProgressBar: View {
    let progress: Double  // 0.0 to 1.0
    let color: Color
    let height: CGFloat
    
    init(progress: Double, color: Color, height: CGFloat = 8) {
        self.progress = progress
        self.color = color
        self.height = height
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let safeWidth = width.isFinite && width >= 0 ? width : 0
            let clampedProgress = max(0, min(progress, 1.0))
            let progressWidth = max(0, safeWidth * clampedProgress)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.full)
                    .fill(Color(hex: "#2C2C2E"))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: AppRadius.full)
                    .fill(color)
                    .frame(width: progressWidth, height: height)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressBar(progress: 0.51, color: Color(hex: "#FF6B47"))
        ProgressBar(progress: 0.42, color: Color(hex: "#3B82F6"))
    }
    .padding()
    .background(Color.black)
}
