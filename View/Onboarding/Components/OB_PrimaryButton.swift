//
//  OB_PrimaryButton.swift
//  Flamora app
//
//  Onboarding - Primary CTA Button
//

import SwiftUI

struct OB_PrimaryButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: AppTypography.body, weight: .semibold))
                .foregroundColor(AppColors.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(14)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1.0)
        .padding(.horizontal, 24)
    }
}

#Preview {
    OB_PrimaryButton(title: "Continue", action: {})
        .background(AppBackgroundView())
}
