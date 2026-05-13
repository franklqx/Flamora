//
//  LegendItemView.swift
//  Meridian
//
//  Shared chart-legend item used by SimulatorView (Home).
//  Two visual styles:
//    .dot  — filled circle 8×8  (sandbox shell)
//    .dash — filled capsule 18×3 (simulator chart)
//

import SwiftUI

struct LegendItemView: View {

    enum Style {
        case dot   // Circle 8×8
        case dash  // Capsule 18×3
    }

    let color: Color
    let label: String
    var style: Style = .dash

    var body: some View {
        HStack(spacing: 6) {
            switch style {
            case .dot:
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            case .dash:
                Capsule()
                    .fill(color)
                    .frame(width: 18, height: 3)
            }
            Text(label)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        LegendItemView(color: AppColors.accentBlueBright, label: "Adjusted", style: .dash)
        LegendItemView(color: AppColors.surfaceBorder, label: "Plan baseline", style: .dash)
        LegendItemView(color: AppColors.budgetOrange, label: "Adjusted", style: .dot)
        LegendItemView(color: AppColors.overlayWhiteForegroundMuted, label: "Current", style: .dot)
    }
    .padding()
    .background(AppColors.surface)
}
