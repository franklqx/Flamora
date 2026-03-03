//
//  OBV2_SelectionCard.swift
//  Flamora app
//
//  V2 Onboarding - Selection Card Component
//

import SwiftUI

struct OBV2_SelectionCard: View {
    let emoji: String
    let title: String
    var subtitle: String = ""
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textPrimary)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.backgroundCard)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
