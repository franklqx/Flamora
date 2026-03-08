//
//  OB_PrimaryButton.swift
//  Flamora app
//
//  Onboarding - Primary CTA Button (统一样式)
//

import SwiftUI
import UIKit

struct OB_PrimaryButton: View {
    var title: String = "Continue"
    var isValid: Bool = true
    /// 为 false 时不含外层 padding，适用于自定义布局（如按钮下方有副标题）
    var includeContainerPadding: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.bodyRegular)
                .fontWeight(.semibold)
                .foregroundColor(isValid ? .black : AppColors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isValid ? Color.white : AppColors.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .disabled(!isValid)
        .modifier(ContainerPaddingModifier(include: includeContainerPadding))
    }
}

private struct ContainerPaddingModifier: ViewModifier {
    let include: Bool
    func body(content: Content) -> some View {
        if include {
            content
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, 0)
        } else {
            content
        }
    }
}

#Preview {
    OB_PrimaryButton(title: "Continue", action: {})
        .background(AppBackgroundView())
}
