//
//  OB_PrimaryButton.swift
//  Flamora app
//
//  Onboarding - Primary CTA Button (统一样式)
//

import SwiftUI
import UIKit

struct OB_PrimaryButton: View {
    enum Style {
        case ctaBlack
        case ctaWhite
    }

    var title: String = "Continue"
    var isValid: Bool = true
    var style: Style = .ctaBlack
    /// 为 false 时不含外层 padding，适用于自定义布局（如按钮下方有副标题）
    var includeContainerPadding: Bool = true
    let action: () -> Void

    private var foregroundColor: Color {
        if isValid {
            return style == .ctaBlack ? AppColors.ctaWhite : AppColors.textInverse
        }
        return AppColors.inkSoft
    }

    private var backgroundColor: Color {
        if isValid {
            return style == .ctaBlack ? AppColors.ctaBlack : AppColors.ctaWhite
        }
        return AppColors.glassCardBg
    }

    private var strokeColor: Color {
        if isValid {
            return style == .ctaBlack ? AppColors.ctaBlack : AppColors.glassCardBorder
        }
        return AppColors.inkBorder
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.bodyRegular)
                .fontWeight(.semibold)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .stroke(strokeColor, lineWidth: 1)
                )
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
