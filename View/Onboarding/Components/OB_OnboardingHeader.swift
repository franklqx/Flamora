//
//  OB_OnboardingHeader.swift
//  Meridian
//
//  Onboarding - Unified header: back button + progress bar + step text
//  统一返回键与进度条布局，参考 Financial Snapshot 样式
//

import SwiftUI

struct OB_OnboardingHeader: View {
    let onBack: () -> Void
    let current: Int
    var total: Int = 10

    static let height: CGFloat = 44  // back button row, header at top (no top padding)

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            OB_BackButton(action: onBack)

            GeometryReader { geo in
                let barWidth = geo.size.width
                let segmentWidth = barWidth / CGFloat(total)
                let fillWidth = segmentWidth * CGFloat(current)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.glassCardBg)
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: AppColors.gradientShellAccent,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, fillWidth), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 44)

            Text("\(current) of \(total)")
                .font(.label)
                .foregroundColor(AppColors.inkMeta)
                .tracking(0.8)
                .lineLimit(1)
                .padding(.leading, AppSpacing.sm)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, 0)
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack {
            OB_OnboardingHeader(onBack: {}, current: 3, total: 10)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
