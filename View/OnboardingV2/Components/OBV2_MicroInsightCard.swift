//
//  OBV2_MicroInsightCard.swift
//  Flamora app
//
//  V2 Onboarding - Micro Insight Card with slide-up animation
//

import SwiftUI

struct OBV2_MicroInsightCard: View {
    let emoji: String
    let text: String
    var highlightText: String = ""

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(emoji)
                .font(.system(size: 24))

            if highlightText.isEmpty || !text.contains(highlightText) {
                Text(text)
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                buildHighlightedText()
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(AppRadius.md)
        .offset(y: isVisible ? 0 : 20)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = true
            }
        }
    }

    @ViewBuilder
    private func buildHighlightedText() -> some View {
        let parts = text.components(separatedBy: highlightText)
        (Text(parts[0])
            .foregroundColor(AppColors.textSecondary) +
         Text(highlightText)
            .foregroundColor(AppColors.textPrimary)
            .bold() +
         Text(parts.dropFirst().joined(separator: highlightText))
            .foregroundColor(AppColors.textSecondary))
            .font(.bodySmall)
    }
}
