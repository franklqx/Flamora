//
//  OBV2_BackButton.swift
//  Flamora app
//
//  V2 Onboarding - Back Arrow Button
//

import SwiftUI

struct OBV2_BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
}
