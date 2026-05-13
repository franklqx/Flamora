//
//  SheetPrimaryCTAButton.swift
//  Meridian
//

import SwiftUI

struct SheetPrimaryCTAButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.sheetPrimaryButton)
                .foregroundStyle(AppColors.ctaWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .fill(AppColors.ctaBlack)
                        .shadow(color: AppColors.glassCardShadow, radius: 16, y: 8)
                )
        }
        .buttonStyle(.plain)
    }
}
