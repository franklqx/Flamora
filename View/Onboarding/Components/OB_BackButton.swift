//
//  OB_BackButton.swift
//  Flamora app
//
//  Onboarding - 屏幕左上角返回键
//

import SwiftUI

struct OB_BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.h3)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OB_BackButton(action: {})
        .background(AppBackgroundView())
}
